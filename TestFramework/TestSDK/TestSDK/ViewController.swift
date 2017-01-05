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
import GPSDK

class ViewController: UIViewController {

    @IBOutlet weak var testLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let service = GPService()
        
        do {
            try service.initService(url:        ReaderCredentials.url,
                                    instanceId: ReaderCredentials.instanceId,
                                    bundleId:   ReaderCredentials.bundleId,
                                    userId:     ReaderCredentials.userId,
                                    password:   ReaderCredentials.password,
                                    
                                    languageId:nil,
                                    alwaysLoadFromServer: false,
                                    expireAfter: 0)
        } catch GPService.GPError.languageNotSupported {
            print("This language is not supported...")
        } catch GPService.GPError.requestServerError(let errorDescription) {
            print("Request server error: " + errorDescription)
        } catch GPService.GPError.HTTPError(let statusCode) {
            print("Request server error: HTTP \(statusCode)")
        } catch {
        }
        
        testLabel.text = service.localizedString("Key1", nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

