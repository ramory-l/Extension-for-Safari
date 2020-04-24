//
//  ActionViewController.swift
//  Extension
//
//  Created by Mikhail Strizhenov on 23.04.2020.
//  Copyright © 2020 Mikhail Strizhenov. All rights reserved.
//

import UIKit
import MobileCoreServices

class ActionViewController: UIViewController {
    var recentScripts = [CodeEx]()
    
    @IBOutlet var script: UITextView!
    
    var pageTitle = ""
    var pageURL = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        let scriptExamplesButton = UIBarButtonItem(title: "Examples", style: .plain, target: self, action: #selector(handfulExamples))
        let recentScriptsButton = UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(gotoRecentOfScripts))
        navigationItem.leftBarButtonItems = [scriptExamplesButton, recentScriptsButton]
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        
        if let inputItem = extensionContext?.inputItems.first as? NSExtensionItem {
            if let itemProvider = inputItem.attachments?.first {
                itemProvider.loadItem(forTypeIdentifier: kUTTypePropertyList as String) { [weak self] (dict, error) in
                    guard let itemDictionary = dict as? NSDictionary else { return }
                    guard let javaScriptValues = itemDictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary else { return }
                    self?.pageTitle = javaScriptValues["title"] as? String ?? ""
                    self?.pageURL = javaScriptValues["URL"] as? String ?? ""
                    DispatchQueue.main.async {
                        self?.title = self?.pageTitle
                    }
                }
            }
        }
        
        if let savedScripts = UserDefaults.standard.object(forKey: "recentScripts") as? Data {
            let jsonDecoder = JSONDecoder()
            do {
                recentScripts = try jsonDecoder.decode([CodeEx].self, from: savedScripts)
            } catch {
                print("Failed to load scripts.")
            }
        }
    }

    @IBAction func done() {
        let item = NSExtensionItem()
        let argument: NSDictionary = ["customJavaScript": script.text as String]
        let webDictionary: NSDictionary = [NSExtensionJavaScriptFinalizeArgumentKey: argument]
        let customJavaScript = NSItemProvider(item: webDictionary, typeIdentifier: kUTTypePropertyList as String)
        item.attachments = [customJavaScript]
        extensionContext?.completeRequest(returningItems: [item])
        let recentScript = CodeEx(date: Date(), site: pageURL, script: script.text)
        recentScripts.append(recentScript)
        save()
    }
    
    @objc func adjustForKeyboard(notification: Notification) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardScreenEndFrame = keyboardValue.cgRectValue
        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)
        
        if notification.name == UIResponder.keyboardWillHideNotification {
            script.contentInset = .zero
        } else {
            script.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardViewEndFrame.height - view.safeAreaInsets.bottom, right: 0)
            script.scrollIndicatorInsets = script.contentInset
            
            let selectedRange = script.selectedRange
            script.scrollRangeToVisible(selectedRange)
        }
    }
    
    @objc func handfulExamples() {
        let ac = UIAlertController(title: "Prewritten examples of JS code", message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "alert(document.title)", style: .default) { [weak self] _ in
            self?.script.text = "alert(document.title)"
            self?.done()
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
    
    
    @objc func gotoRecentOfScripts() {
        let tvc = TableViewController()
        tvc.recentScripts = recentScripts
        navigationController?.pushViewController(tvc, animated: true)
    }
    
    
    func save() {
        let jsonEncoder = JSONEncoder()
        
        if let savedData = try? jsonEncoder.encode(recentScripts) {
            let defaults = UserDefaults.standard
            defaults.set(savedData, forKey: "recentScripts")
        } else {
            print("Failed to save scripts.")
        }
    }
}
