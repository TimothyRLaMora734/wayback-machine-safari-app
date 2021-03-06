//
//  SafariExtensionViewController.swift
//  Wayback Machine Extension
//
//  Created by mac-admin on 9/29/18.
//

import Foundation
import Cocoa
import SafariServices

class WMEMainVC: WMEBaseVC {

    static let shared: WMEMainVC = {
        return WMEMainVC()
    }()

    @IBOutlet weak var txtSearch: NSSearchField!
    @IBOutlet weak var boxWayback: NSBox!
    @IBOutlet weak var txtSavedInfo: NSTextField!
    @IBOutlet weak var txtLastSaved: NSTextField!
    @IBOutlet weak var indProgress: NSProgressIndicator!
    @IBOutlet weak var btnSavePage: NSButton!
    //@IBOutlet weak var txtSaveLabel: NSTextField!
    @IBOutlet weak var chkSaveOutlinks: NSButton!
    @IBOutlet weak var chkSaveScreenshots: NSButton!
    @IBOutlet weak var btnSiteMap: NSButton!
    @IBOutlet weak var btnLoginout: NSButton!

    var waybackCountPending: Bool = false

    ///////////////////////////////////////////////////////////////////////////////////
    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        txtSearch.delegate = self
        indProgress.stopAnimation(nil)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        loadSearchField()

        // update login UI & restore button states
        if WMEGlobal.shared.isLoggedIn() {
            let userData = WMEGlobal.shared.getUserData()
            let email = userData?["email"] as? String
            updateLoginUI(true, username: email)
            enableSavePageUI(WMEGlobal.shared.savePageEnabled)
        } else {
            updateLoginUI(false)
        }
        enableSiteMapUI(WMEGlobal.shared.siteMapEnabled)

        // update saved info
        txtSavedInfo.stringValue = ""
        updateSavedInfo(url: WMEGlobal.shared.urlCountLastURL)
        //grabURL { (url) in self.updateSavedInfo(url: url) }  // use when pressing Enter in search box
    }

    ///////////////////////////////////////////////////////////////////////////////////
    // MARK: - Helper Functions

    func updateLoginUI(_ isLoggedIn: Bool, username: String? = nil) {
        if isLoggedIn {
            let uname = username ?? "logged in"
            boxWayback.title = "Wayback (\(uname))"
            btnSavePage.isEnabled = true
            btnSavePage.title = "Save Page Now"
            btnLoginout.title = "Logout"
            //txtSaveLabel.textColor = NSColor.labelColor
            chkSaveOutlinks.isEnabled = true
            chkSaveScreenshots.isEnabled = true
        } else {
            boxWayback.title = "Wayback (logged out)"
            btnSavePage.isEnabled = false
            btnSavePage.title = "Login to Save Page"
            btnLoginout.title = "Login"
            //txtSaveLabel.textColor = NSColor.disabledControlTextColor
            chkSaveOutlinks.state = .off
            chkSaveOutlinks.isEnabled = false
            chkSaveScreenshots.state = .off
            chkSaveScreenshots.isEnabled = false
        }
    }

    func enableSavePageUI(_ enable:Bool) {
        if enable {
            btnSavePage.title = "Save Page Now"
            indProgress.stopAnimation(nil)
        } else {
            btnSavePage.title = "Saving..."
            indProgress.startAnimation(nil)
        }
        // save state in case view disappears
        WMEGlobal.shared.savePageEnabled = enable
    }

    func enableSiteMapUI(_ enable:Bool) {
        if enable {
            btnSiteMap.title = "Site Map"
            btnSiteMap.isEnabled = true
        } else {
            btnSiteMap.title = "Loading..."
            btnSiteMap.isEnabled = false
        }
        // save state in case view disappears
        WMEGlobal.shared.siteMapEnabled = enable
    }

    /// Restore search field from persistent storage.
    func loadSearchField() {
        let userData = WMEGlobal.shared.getUserData()
        if let txt = userData?["searchField"] as? String {
            txtSearch.stringValue = txt
        }
    }

    /// Save search field to persistent storage.
    func saveSearchField(text: String?) {
        if var userData = WMEGlobal.shared.getUserData() {
            userData["searchField"] = text
            WMEGlobal.shared.saveUserData(userData: userData)
        }
    }

    /// Percent encode any whitespace for given URL.
    func encodeWhitespace(_ url: String?) -> String? {
        return url?.addingPercentEncoding(withAllowedCharacters: (CharacterSet.whitespacesAndNewlines).inverted)
    }

    /// Grab URL from search field if it's not empty, otherwise grab from active open browser tab.
    func grabURL(completion: @escaping (String?) -> Void) {
        if !txtSearch.stringValue.isEmpty {
            completion(encodeWhitespace(txtSearch.stringValue))
        } else {
            WMEUtil.shared.getActivePageURL { (url) in
                completion(url)
            }
        }
    }

    func updateSavedInfo(wbc: WMWaybackCount?) {
        if let wbc = wbc {
            if wbc.count == 1 {
                self.txtSavedInfo.stringValue = "Saved once."
            } else if wbc.count > 1 {
                self.txtSavedInfo.stringValue = "Saved \(wbc.count.withCommas()) times."
            } else {
                self.txtSavedInfo.stringValue = "This page was never archived."
            }
            if let recent = wbc.lastDate {
                let df = DateFormatter()
                df.dateStyle = .medium
                df.timeStyle = .short
                self.txtLastSaved.stringValue = "Last Saved " + df.string(from: recent)
            } else {
                self.txtLastSaved.stringValue = ""
            }
        } else {
            self.txtSavedInfo.stringValue = ""
            self.txtLastSaved.stringValue = ""
        }
    }

    func updateSavedInfo(url: String?) {
        guard let url = url else {
            self.txtSavedInfo.stringValue = ""
            self.txtLastSaved.stringValue = ""
            return
        }
        if url == "PRIVATE" {
            self.txtSavedInfo.stringValue = "Private Browsing Enabled."
            self.txtLastSaved.stringValue = "Enter website below for stats."
        } else if url == "SEARCHING" {
            self.txtSavedInfo.stringValue = ""
            self.txtLastSaved.stringValue = "Searching..."
        } else {
            self.updateSavedInfo(wbc: WMEGlobal.shared.urlCountCache[url])
        }
    }

    func fetchAndShowSavedInfo(url: String) {
        if self.waybackCountPending == false {
            self.waybackCountPending = true
            self.updateSavedInfo(url: "SEARCHING")
            WMSAPIManager.shared.getWaybackCount(url: url) { (originalURL, count, firstDate, lastDate) in
                self.waybackCountPending = false
                if let count = count {
                    let wbc = WMWaybackCount(count: count, firstDate: firstDate, lastDate: lastDate)
                    self.updateSavedInfo(wbc: wbc)
                } else {
                    self.updateSavedInfo(wbc: nil)
                }
            }
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////
    // MARK: - Actions

    /// Go to the Wayback Machine website.
    @IBAction func waybackLogoClicked(_ sender: Any) {
        WMEUtil.shared.openTabWithURL(url: "https://web.archive.org/")
    }

    @IBAction func searchEnterPressed(_ sender: NSSearchField) {
        if (DEBUG_LOG) { NSLog("*** searchEnterPressed() sender: \(sender)") }
        if sender === self.txtSearch! {
            // take user-entered web address and fetch Wayback info
            let text = self.txtSearch.stringValue
            if (DEBUG_LOG) { NSLog("*** txtSearch: \(text)") }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, let url = encodeWhitespace(trimmed) {
                fetchAndShowSavedInfo(url: url)
            } else {
                updateSavedInfo(wbc: nil)
            }
        }
    }

    @IBAction func savePageNowClicked(_ sender: Any) {

        if WMEGlobal.shared.savePageEnabled {
            var options: WMSAPIManager.CaptureOptions = [.allErrors]
            if chkSaveOutlinks.state == .on {
                options.append(.outlinks)
                options.append(.emailOutlinks)
            }
            if chkSaveScreenshots.state == .on {
                options.append(.screenshot)
            }
            savePageNow(options: options)
        }
    }

    func savePageNow(options: WMSAPIManager.CaptureOptions) {

        enableSavePageUI(false)
        grabURL { (url) in
            guard let url = url else {
                self.enableSavePageUI(true)
                WMEUtil.shared.showMessage(msg: "Missing URL", info: "Please type a URL in the search field or open a URL in the web browser.")
                return
            }
            guard let userData = WMEGlobal.shared.getUserData(),
                let accessKey = userData["s3accesskey"] as? String,
                let secretKey = userData["s3secretkey"] as? String else
            {
                self.enableSavePageUI(true)
                WMEUtil.shared.showMessage(msg: "Not Logged In?", info: "Try logging out and back in again.")
                return
            }

            WMSAPIManager.shared.capturePage(url: url, accessKey: accessKey, secretKey: secretKey, options: options) {
                (jobId, error) in

                if let jobId = jobId {
                    // short delay before retrieving status
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                        WMSAPIManager.shared.getPageStatus(jobId: jobId, accessKey: accessKey, secretKey: secretKey,
                        pending: {
                            (resources) in
                            // FIXME: Pending count may not always update after view disappears + reappears?
                            let resCount = resources?.count ?? 0
                            if (DEBUG_LOG) { NSLog("*** pending count: \(resCount)") }
                            self.btnSavePage.title = "Saving... \(resCount)"
                        },
                        completion: {
                            (archiveURL, errMsg, json) in

                            if (DEBUG_LOG) { NSLog("*** capturePage completed: archiveURL: \(String(describing: archiveURL)) errMsg: \(String(describing: errMsg))") }
                            self.enableSavePageUI(true)
                            if let archiveURL = archiveURL {

                                // increment counter, since there is a delay when calling API in receiving updated count
                                if WMEGlobal.shared.urlCountCache[url] != nil {
                                    WMEGlobal.shared.urlCountCache[url]?.count += 1
                                    WMEGlobal.shared.urlCountCache[url]?.lastDate = Date()
                                    SFSafariApplication.setToolbarItemsNeedUpdate()
                                }

                                // report resource and outlink counts
                                var infoMsg: String = "The following website has been archived:\n\(url)\n\n"
                                if let resources = json?["resources"] as? [String] {
                                    infoMsg += "\(resources.count) Resources saved.\n"
                                }
                                if let outlinks = json?["outlinks"] as? [String: Any] {
                                    infoMsg += "\(outlinks.count) Outlinks saving in progress.\n"
                                }
                                if (json?["screenshot"] as? String) != nil {
                                    infoMsg += "Screenshot saved.\n"
                                }
                                if (DEBUG_LOG) { NSLog("*** capturePage Saved: %@", infoMsg) }

                                /*
                                 FIXME: NSAlert fails to show if MainVC not visible.
                                 I haven't been able to solve this issue.
                                 I suspect that it's due to NSAlert() not having a parent window
                                 to associate with, but there's no way to supply this info.
                                 Console says:
                                   "*** Assertion failure in +[NSViewServiceMarshal serviceMarshalForAppModalSession:]"
                                   "An uncaught exception was raised"
                                 Only idea I came up with is to send a message to some injected JS that runs:
                                   if (window.confirm("message")) { window.open("url", "_blank "); }
                                */

                                // alert to view saved info
                                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                                    let alert = NSAlert()
                                    alert.messageText = "Page Saved"
                                    alert.informativeText = infoMsg
                                    alert.alertStyle = .informational
                                    alert.addButton(withTitle: "OK")
                                    alert.addButton(withTitle: "Copy Wayback URL")
                                    let mr = alert.runModal()
                                    if mr == .alertSecondButtonReturn {
                                        // copy URL to clipboard (this works)
                                        if (DEBUG_LOG) { NSLog("*** Copy URL button clicked: \(archiveURL)") }
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(archiveURL, forType: .string)

                                        // FIXME: Can't open URL due to Safari bug. see openTabWithURL() in WMEUtil.
                                        //if (DEBUG_LOG) { NSLog("*** View Archive button clicked") }
                                        // Neither of these work:
                                        //WMEUtil.shared.openTabWithURL(url: archiveURL)
                                        //self.newestClicked(nil)
                                    }
                                }
                            } else {
                                if (DEBUG_LOG) { NSLog("*** capturePage Failed1: %@", (errMsg ?? "Unknown Error")) }
                                WMEUtil.shared.showMessage(msg: "Save Page Failed", info: (errMsg ?? "Unknown Error"))
                            }
                        })
                    }
                } else {
                    self.enableSavePageUI(true)
                    if (DEBUG_LOG) { NSLog("*** capturePage Failed2: %@", (error?.localizedDescription ?? "Unknown Error")) }
                    WMEUtil.shared.showMessage(msg: "Save Page Failed", info: (error?.localizedDescription ?? "Unknown Error"))
                }
            }
        }
    }

    /// Check if `url` is available in Wayback Machine, then open Wayback version in web browser.
    /// - parameter url: Archived website to view.
    /// - parameter waybackPath: Pass in `WMSAPIManager.WM_OLDEST`, `.WM_NEWEST` or `.WM_OVERVIEW`.
    ///
    func openInWayback(url: String?, waybackPath: String) {

        guard let url = url else {
            WMEUtil.shared.showMessage(msg: "Missing URL", info: "Please type a URL in the search field or open a URL in the web browser.")
            return
        }
        WMSAPIManager.shared.checkAvailability(url: url) { (waybackURL, originalURL) in
            guard waybackURL != nil else {
                WMEUtil.shared.showMessage(msg: "Not in Internet Archive", info: "The URL is not in Internet Archive. We would suggest to archive the URL by clicking Save Page Now.")
                return
            }
            let fullURL = WMSAPIManager.WM_BASE_URL + waybackPath + originalURL
            WMEUtil.shared.openTabWithURL(url: fullURL)
        }
    }

    @IBAction func oldestClicked(_ sender: Any?) {
        grabURL { (url) in
            self.openInWayback(url: url, waybackPath: WMSAPIManager.WM_OLDEST)
        }
    }

    @IBAction func overviewClicked(_ sender: Any?) {
        grabURL { (url) in
            self.openInWayback(url: url, waybackPath: WMSAPIManager.WM_OVERVIEW)
        }
    }

    @IBAction func newestClicked(_ sender: Any?) {
        grabURL { (url) in
            self.openInWayback(url: url, waybackPath: WMSAPIManager.WM_NEWEST)
        }
    }

    @IBAction func alexaClicked(_ sender: Any) {
        grabURL { (url) in
            guard let url = url else {
                WMEUtil.shared.showMessage(msg: "Missing URL", info: "Please type a URL in the search field or open a URL in the web browser.")
                return
            }
            guard let urlHost = URL(string: WMSAPIManager.shared.fullWebURL(url))?.host else {
                WMEUtil.shared.showMessage(msg: "Incorrect URL", info: "Please type a correct URL in the search field or web browser.")
                return
            }
            // search alexa
            WMEUtil.shared.openTabWithURL(url: "https://www.alexa.com/siteinfo/" + urlHost)
        }
    }
    
    @IBAction func whoisClicked(_ sender: Any) {
        grabURL { (url) in
            guard let url = url else {
                WMEUtil.shared.showMessage(msg: "Missing URL", info: "Please type a URL in the search field or open a URL in the web browser.")
                return
            }
            guard let urlHost = URL(string: WMSAPIManager.shared.fullWebURL(url))?.host else {
                WMEUtil.shared.showMessage(msg: "Incorrect URL", info: "Please type a correct URL in the search field or web browser.")
                return
            }
            // search whois
            WMEUtil.shared.openTabWithURL(url: "https://www.whois.com/whois/" + urlHost)
        }
    }
    
    @IBAction func tweetsClicked(_ sender: Any) {
        grabURL { (url) in
            guard let url = url else {
                WMEUtil.shared.showMessage(msg: "Missing URL", info: "Please type a URL in the search field or open a URL in the web browser.")
                return
            }
            let fullURL = WMSAPIManager.shared.fullWebURL(url)
            guard let urlHost = URL(string: fullURL)?.host, let urlPath = URL(string: fullURL)?.path else {
                WMEUtil.shared.showMessage(msg: "Missing URL", info: "Please type a URL in the search field or open a URL in the web browser.")
                return
            }
            // search twitter
            WMEUtil.shared.openTabWithURL(url: "https://twitter.com/search?q=" + urlHost + urlPath)
        }
    }
    
    @IBAction func siteMapClicked(_ sender: Any) {
        if (DEBUG_LOG) { NSLog("*** siteMapClicked()") }

        enableSiteMapUI(false)
        let sUrl = encodeWhitespace(txtSearch.stringValue) ?? ""
        if sUrl.isEmpty {
            // use the current url in web browser
            if (DEBUG_LOG) { NSLog("*** is empty") }
            WMEUtil.shared.getActivePageURL { (url) in
                self.showSiteMap(url: url)
            }
        } else {
            // open the url in web browser before showing the site map
            if (DEBUG_LOG) { NSLog("*** not empty: \(sUrl)") }
            let tUrl = WMSAPIManager.shared.fullWebURL(sUrl)
            if (DEBUG_LOG) { NSLog("*** open url: \(tUrl)") }
            WMEUtil.shared.openTabWithURL(url: tUrl) {
                if (DEBUG_LOG) { NSLog("*** openTabWithURL completed") }
                // clear search field in case user clicks "Site Map" button again
                self.txtSearch.stringValue = ""
                self.saveSearchField(text: "")
                // short delay to allow website to load
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                    WMEUtil.shared.getActivePageURL { (url) in
                        self.showSiteMap(url: url)
                    }
                }
            }
        }
    }

    func showSiteMap(url: String?) {
        if (DEBUG_LOG) { NSLog("*** showSiteMap() url: \(String(describing: url))") }
        guard let url = url else {
            enableSiteMapUI(true)
            WMEUtil.shared.showMessage(msg: "Missing URL", info: "Please type a URL in the search field or open a URL in the web browser.")
            return
        }
        guard let urlHost = URL(string: WMSAPIManager.shared.fullWebURL(url))?.host else {
            enableSiteMapUI(true)
            WMEUtil.shared.showMessage(msg: "Incorrect URL", info: "Please type a correct URL in the search field or web browser.")
            return
        }
        // display loader in webpage
        WMEUtil.shared.dispatchMessage(messageName: "DISPLAY_RT_LOADER", userInfo: ["visible": true])
        WMSAPIManager.shared.getSiteMapData(url: urlHost) { (data) in
            if let data = data {
                WMEUtil.shared.dispatchMessage(messageName: "RADIAL_TREE", userInfo: ["url": urlHost, "data": data])
                self.enableSiteMapUI(true)
            } else {
                self.enableSiteMapUI(true)
                WMEUtil.shared.showMessage(msg: "Site Map Failed", info: "Loading the Site Map failed.")
            }
        }
    }
    
    @IBAction func facebookClicked(_ sender: Any) {
        grabURL { (url) in
            guard let url = url else {
                WMEUtil.shared.showMessage(msg: "Missing URL", info: "Please type a URL in the search field or open a URL in the web browser.")
                return
            }
            // share on facebook
            WMEUtil.shared.openTabWithURL(url: "https://www.facebook.com/sharer/sharer.php?u=" + url)
        }
    }
    
    @IBAction func twitterClicked(_ sender: Any) {
        grabURL { (url) in
            guard let url = url else {
                WMEUtil.shared.showMessage(msg: "Missing URL", info: "Please type a URL in the search field or open a URL in the web browser.")
                return
            }
            // share on twitter
            WMEUtil.shared.openTabWithURL(url: "http://twitter.com/share?url=" + url)
        }
    }
    
    @IBAction func linkedinClicked(_ sender: Any) {
        grabURL { (url) in
            guard let url = url else {
                WMEUtil.shared.showMessage(msg: "Missing URL", info: "Please type a URL in the search field or open a URL in the web browser.")
                return
            }
            // share on linkedin
            WMEUtil.shared.openTabWithURL(url: "https://www.linkedin.com/shareArticle?url=" + url)
        }
    }
    
    @IBAction func aboutClicked(_ sender: Any) {
        view.window?.contentViewController = WMEAboutVC()
    }

    @IBAction func loginoutClicked(_ sender: Any) {

        if WMEGlobal.shared.isLoggedIn() {
            // logout clicked, so clear any stored data
            updateLoginUI(false)
            if let userData = WMSAPIManager.shared.logout(userData: WMEGlobal.shared.getUserData()) {
                WMEGlobal.shared.saveUserData(userData: userData)
            }
        } else {
            // login clicked, so go to login view
            view.window?.contentViewController = WMELoginVC()
        }
    }

}

///////////////////////////////////////////////////////////////////////////////////
// MARK: - NSSearchFieldDelegate

extension WMEMainVC: NSSearchFieldDelegate {

    func controlTextDidEndEditing(_ obj: Notification) {
        //if (DEBUG_LOG) { NSLog("*** controlTextDidEndEditing() obj: \(obj)") }
        saveSearchField(text: txtSearch.stringValue)
    }

}
