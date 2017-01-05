/*
 * Copyright IBM Corp. 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import UIKit

open class GPService: NSObject {
    
    var args = Dictionary<String, String>()
    var bcp47Identifiers = Array<String>()
    var resultMap: [String: String] = [:]
    
    public enum GPError: Error
    {
        case languageNotSupported
        case requestServerError(String)
        case HTTPError(Int)
    }
    
    public override init() {
        let appleIdentifiers = NSLocale.availableLocaleIdentifiers
        
        for beforeValue in appleIdentifiers {
            let afterValue = beforeValue.replacingOccurrences(of: "_", with: "-")
            bcp47Identifiers.append(afterValue)
        }
    }
    
    open func initService(url:String!, instanceId:String!, bundleId: String!, userId:String!, password:String!, languageId:String?, alwaysLoadFromServer:Bool!, expireAfter:Int!) throws {
        if args["url"] != nil {
            args.updateValue(url,forKey:"url")
        } else {
            args["url"] = url
        }
        if args["instanceId"] != nil {
            args.updateValue(instanceId,forKey:"instanceId")
        } else {
            args["instanceId"] = instanceId
        }
        if args["userId"] != nil {
            args.updateValue(userId,forKey:"userId")
        } else {
            args["userId"] = userId
        }
        if args["password"] != nil {
            args.updateValue(password,forKey:"password")
        } else {
            args["password"] = password
        }
        if args["expireAfter"] != nil {
            args.updateValue(String(expireAfter),forKey:"expireAfter")
        } else {
            args["expireAfter"] = String(expireAfter)
        }
        
        try connectServer(bundleId, languageId, alwaysLoadFromServer)
    }
    
    
    func connectServer(_ bundleId:String!, _ languageId:String?, _ alwaysLoadFromServer:Bool!) throws{
        
        let sessionConfig = URLSessionConfiguration.default
        /* Create session, and optionally set a NSURLSessionDelegate. */
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        
        var strLan = "en"
        
        if let _ = languageId {
            strLan = languageId!
        } else {
            if let appleLangs = UserDefaults.standard.object(forKey: "AppleLanguages") as? [String] {
                strLan = appleLangs[0]
                let strLans = strLan.components(separatedBy: "-")
                var length = strLans.count - 2
                if (length < 0) {
                    length = 0
                }
                var strLanBuf = ""
                for i in 0...length {
                    if (i != length) {
                        strLanBuf.append(strLans[i] + "-")
                    } else {
                        strLanBuf.append(strLans[i])
                    }
                }
                strLan = strLanBuf
            }
        }
        
        strLan = strLan.replacingOccurrences(of: "_", with: "-")
        
        if (bcp47Identifiers.contains(strLan) == false) {
            throw GPError.languageNotSupported
        }
        
        
        if let supportedLans = try? localizations(bundleId) {
            if (supportedLans?.contains(strLan) == false) {
                throw GPError.languageNotSupported
            }
        }
        
        let reqUrl = args["url"]! + "/" + args["instanceId"]! + "/v2/bundles/" + bundleId + "/" + strLan;
        
        guard let URL = URL(string: reqUrl) else {return}
        let request = NSMutableURLRequest(url: URL)
        request.httpMethod = "GET"
        
        let str = args["userId"]! + ":" + args["password"]!
        let utf8str = str.data(using: String.Encoding.utf8)
        
        
        if let base64EncodedString = utf8str?.base64EncodedString() {
            request.addValue("Basic " + base64EncodedString, forHTTPHeaderField: "Authorization")
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var errorDescription = ""
        
        var statusCode = 200
        
        let storedFileName = NSHomeDirectory() + "/" + args["instanceId"]! + "_" + bundleId + "_" + strLan
        
        if (alwaysLoadFromServer == true) {
            /* Start a new Task */
            let task = session.dataTask(with: request as URLRequest, completionHandler: {(data: Data?, response: URLResponse?, error: Error?) -> Void in
                if (error == nil) {
                    // Success
                    statusCode = (response as! HTTPURLResponse).statusCode
                    
                    if (statusCode == 200) {
                        if let dt = data {
                            let jsonData = GPJSON(data: dt)
                            self.resultMap = jsonData.getResourceStrings()
                        }
                    }
                    
                    if (self.resultMap.isEmpty == false) {
                        NSKeyedArchiver.archiveRootObject(self.resultMap, toFile: storedFileName)
                     }
                }
                else {
                    // Failure
                    errorDescription = error!.localizedDescription
                }
                semaphore.signal()
            })
            task.resume()
            session.finishTasksAndInvalidate()
        } else {
            var requestServer = false
            // Find result in cache first
            let manager = FileManager.default
            let exist = manager.fileExists(atPath: storedFileName)
            
            if (exist == true) {
                let attributes = try? manager.attributesOfItem(atPath: storedFileName)
                let creationDate = attributes?[FileAttributeKey.creationDate] as! NSDate
                let fileCreationTimestamp = Int(creationDate.timeIntervalSince1970)

                let now = NSDate()
                let timeInterval:TimeInterval = now.timeIntervalSince1970
                let timeStamp = Int(timeInterval)
                
                let timespan =  timeStamp - fileCreationTimestamp
                let expireAfter:String = args["expireAfter"]!
                if (timespan > Int(expireAfter)!*3600) {
                    requestServer = true
                    try! manager.removeItem(atPath: storedFileName)
                }
            } else {
                requestServer = true
            }
            
            if (requestServer == false) {
                let data = NSKeyedUnarchiver.unarchiveObject(withFile: storedFileName) as! Dictionary<String, String>
                self.resultMap = data
                semaphore.signal()
            }
            else {
                /* Start a new Task */
                let task = session.dataTask(with: request as URLRequest, completionHandler: {(data: Data?, response: URLResponse?, error: Error?) -> Void in
                    if (error == nil) {
                        // Success
                        statusCode = (response as! HTTPURLResponse).statusCode
                        
                        if (statusCode == 200) {
                            if let dt = data {
                                let jsonData = GPJSON(data: dt)
                                self.resultMap = jsonData.getResourceStrings()
                            }

                            if (self.resultMap.isEmpty == false) {
                                NSKeyedArchiver.archiveRootObject(self.resultMap, toFile: storedFileName)
                            }
                        }
                    }
                    else {
                        // Failure
                        errorDescription = error!.localizedDescription
                    }
                    semaphore.signal()
                })
                task.resume()
                session.finishTasksAndInvalidate()
            }
        }
        
        let a = semaphore.wait(timeout: DispatchTime.distantFuture)
        if a == DispatchTimeoutResult.success {
            if (errorDescription == "") {
                if (String(statusCode).hasPrefix("4") || String(statusCode).hasPrefix("5")) {
                    throw GPError.HTTPError(statusCode)
                }
            } else {
                throw GPError.requestServerError(errorDescription)
            }
        }
    }
    
    open func localizedString(_ key:String, _ comment:String?) -> String {
        if let value = self.resultMap[key] {
            return value
        } else {
            return key
        }
    }
    
    open func localizations(_ bundleId:String) throws -> [String]?{
        
        let sessionConfig = URLSessionConfiguration.default
        
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        
        let reqUrl = args["url"]! + "/" + args["instanceId"]! + "/v2/bundles/" + bundleId;
        
        guard let URL = URL(string: reqUrl) else {return nil}
        let request = NSMutableURLRequest(url: URL)
        request.httpMethod = "GET"
        
        let str = args["userId"]! + ":" + args["password"]!
        
        let utf8str = str.data(using: String.Encoding.utf8)
        
        if let base64EncodedString = utf8str?.base64EncodedString() {
            request.addValue("Basic " + base64EncodedString, forHTTPHeaderField: "Authorization")
        }
        
        var supportedLans: [String]?
        
        let semaphore = DispatchSemaphore(value: 0)
        var errorDescription = ""
        
        var statusCode = 200
        
        /* Start a new Task */
        let task = session.dataTask(with: request as URLRequest, completionHandler: {(data: Data?, response: URLResponse?, error: Error?) -> Void in
            if (error == nil) {
                // Success
                statusCode = (response as! HTTPURLResponse).statusCode
                
                if (statusCode == 200) {
                    if let dt = data {
                        let jsonData = GPJSON(data: dt)
                        supportedLans = jsonData.getLanguages()
                    }
                }
                
            } else {
                // Failure
                errorDescription = error!.localizedDescription
            }
            semaphore.signal()
        })
        task.resume()
        session.finishTasksAndInvalidate()
        
        let a = semaphore.wait(timeout: DispatchTime.distantFuture)
        if a == DispatchTimeoutResult.success {
            if (errorDescription == "") {
                if (String(statusCode).hasPrefix("4") || String(statusCode).hasPrefix("5")) {
                    throw GPError.HTTPError(statusCode)
                } else {
                    return supportedLans
                }
            } else {
                throw GPError.requestServerError(errorDescription)
            }
        }
        return nil
    }
    
}
