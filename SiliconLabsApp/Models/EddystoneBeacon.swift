//
//  EddystoneBeacon.swift
//  SiliconLabsApp
//
//  Created by Nicholas Servidio on 2/27/17.
//  Copyright © 2017 SiliconLabs. All rights reserved.
//

import Foundation

final class EddystoneBeacon: NSObject {
    private(set) var url: URL?
    private(set) var namespace: String?
    private(set) var instance: String?
    private(set) var rssi: Int16
    private(set) var txPower: Int

    init(url aURL: URL?, namespace aNamespace: String?, instance anInstance: String?, rssi anRssi: Int16, txPower aTxPower: Int) {
        url = aURL
        namespace = aNamespace
        instance = anInstance
        rssi = anRssi
        txPower = aTxPower
        super.init()
    }

    convenience override init() {
        self.init(url: nil, namespace: nil, instance: nil, rssi: 0, txPower: 0)
    }
}
