//
//  EddystoneScanner.swift
//  SiliconLabsApp
//
//  Created by Nicholas Servidio on 2/23/17.
//  Copyright © 2017 SiliconLabs. All rights reserved.
//

import Foundation
import Eddystone

@objc protocol EddystoneScannerDelegate: class {
    func eddystoneScanner(_ eddystoneScanner: EddystoneScanner, didFindBeacons beacons: [EddystoneBeacon])
}

final class EddystoneScanner: NSObject, ScannerDelegate {

    weak var delegate: EddystoneScannerDelegate?

    func scanForEddystoneBeacons() {
        Eddystone.Scanner.start(self as ScannerDelegate)
    }

    func stopScanningForEddystoneBeacons() {
        Eddystone.Scanner.stopScan()
    }

    // MARK: - ScannerDelegate

    func eddystoneNearbyDidChange() {
        let generics = Scanner.nearby
        let eddystones = generics.map {
            return EddystoneBeacon(url: $0.url, namespace: $0.namespace, instance: $0.instance, rssi: Int16($0.rssi), txPower: $0.txPower)
        }
        self.delegate?.eddystoneScanner(self, didFindBeacons: eddystones)
    }
}
