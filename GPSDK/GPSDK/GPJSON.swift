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


/**
 * Unmarshall JSON as used by GP
 */
public struct GPJSON {
    let obj : NSDictionary?
    
    
    public init(data: Data) {
        obj = try! JSONSerialization.jsonObject(with: data, options: .allowFragments)
            as? NSDictionary
    }
    
    public func getDict(_ forKey: String) -> NSDictionary? {
        return obj! .object(forKey: forKey) as! NSDictionary?
    }
    
    public func getBundle() -> NSDictionary? {
        return getDict("bundle")
    }
    
    public func getLanguages() -> [String]? {
        var supportedLanguages: [String]
        let sourceLanguage =
            getBundle()!
                .object(forKey: "sourceLanguage") as! String?
        let targetLanguages =
            getBundle()!
                .object(forKey: "targetLanguages")
                as! [String]?

        // add all target languages
        
        if (targetLanguages != nil) {
            supportedLanguages = targetLanguages!
        } else {
            supportedLanguages = []
        }
        
        // add source languages
        if(sourceLanguage != nil) {
            supportedLanguages.append(sourceLanguage!)
        }
        return supportedLanguages
    }
    
    
    public func getResourceStrings() -> [String: String]  {
        var resultMap : [String: String] = [:]
        let resourceStrings = getDict("resourceStrings")
        if resourceStrings != nil {
            for (srcKey, tarVal) in resourceStrings! {
                resultMap[srcKey as! String] = tarVal as? String
            }
        }
        return resultMap
    }
}

