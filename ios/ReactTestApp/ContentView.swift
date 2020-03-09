//
// Copyright (c) Microsoft Corporation. All rights reserved.
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.
//

import UIKit
import QRCodeReader

typealias NavigationLink = (String, () -> Void)

private struct SectionData {
    var items: [NavigationLink]
    let footer: String?
}

final class ContentViewController: UITableViewController {
    private let reactInstance: ReactInstance
    private var sections: [SectionData]

    // swiftlint:disable:next weak_delegate
    private lazy var qrCodeReaderDelegate = QRCodeReaderDelegate()

    public init() {
        reactInstance = ReactInstance()
        sections = [SectionData(items: [], footer: nil)]

        super.init(style: .grouped)
        title = "ReactTestApp"

        sections.append(SectionData(
            items: [
                ("Load Embedded JS Bundle", { [weak self] in self?.reactInstance.remoteBundleURL = nil }),
                itemWithRemoteJSBundle()
            ],
            footer: runtimeInfo()
        ))
    }

    required init?(coder: NSCoder) {
        fatalError("\(#function) has not been implemented")
    }

    // MARK: - UIViewController overrides

    public override func viewDidLoad() {
        super.viewDidLoad()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.reactInstance.initReact { components in
                let items: [NavigationLink] = components.map { (name, component) in
                    (component.displayName ?? name, { self?.navigate(to: component, name: name) })
                }
                DispatchQueue.main.async {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.sections[0].items = items
                    strongSelf.tableView.reloadData()
                }
            }
        }
    }

    // MARK: - UITableViewDelegate overrides

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let (_, action) = sections[indexPath.section].items[indexPath.row]
        action()
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - UITableViewDataSource overrides

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let (title, _) = sections[indexPath.section].items[indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        let presentsNewContent = indexPath.section == 0
        cell.accessoryType = presentsNewContent ? .disclosureIndicator : .none
        if let textLabel = cell.textLabel {
            textLabel.text = title
            textLabel.textColor = presentsNewContent ? .label : .link
            textLabel.allowsDefaultTighteningForTruncation = true
            textLabel.numberOfLines = 1
        }
        return cell
    }

    public override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    public override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footer
    }

    // MARK: - Private

    private func itemWithRemoteJSBundle() -> (String, () -> Void) {
        #if targetEnvironment(simulator)
        return (
            "Load From Dev Server", { [weak self] in
                self?.reactInstance.remoteBundleURL = ReactInstance.jsBundleURL()
            }
        )
        #else
        return (
            "Scan QR Code", { [weak self] in
                guard let strongSelf = self else {
                    return
                }

                let builder = QRCodeReaderViewControllerBuilder {
                    $0.reader = QRCodeReader(
                        metadataObjectTypes: [.qr],
                        captureDevicePosition: .back
                    )
                    $0.showSwitchCameraButton = false
                    $0.showOverlayView = true
                    $0.rectOfInterest = CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.4)
                }
                let viewController = QRCodeReaderViewController(builder: builder)
                viewController.delegate = strongSelf.qrCodeReaderDelegate
                strongSelf.present(viewController, animated: true)
            }
        )
        #endif
    }

    private func navigate(to component: Component, name: String) {
        guard let bridge = reactInstance.bridge,
              let navigationController = navigationController else {
            return
        }

        let viewController: UIViewController = {
            if let viewController = RTAViewControllerFromString(name, bridge) {
                return viewController
            }

            let viewController = UIViewController(nibName: nil, bundle: nil)
            viewController.view = RCTRootView(
                bridge: bridge,
                moduleName: name,
                initialProperties: component.initialProperties
            )
            return viewController
        }()
        navigationController.pushViewController(viewController, animated: true)
    }

    private func runtimeInfo() -> String {
        let version: String = {
            guard let version = RCTGetReactNativeVersion() else {
                return "0"
            }

            let major = version[RCTVersionMajor] ?? "0"
            let minor = version[RCTVersionMinor] ?? "0"
            let patch = version[RCTVersionPatch] ?? "0"
            return "\(major).\(minor).\(patch)"
        }()
        return "React Native version: \(version)"
    }
}