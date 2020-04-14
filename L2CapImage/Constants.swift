//
//  Constants.swift
//  L2CapImage
//
//  Created by George Gostev on 08/04/2020.
//  Copyright © 2020 George Gostev. All rights reserved.
//

import Foundation
import CoreBluetooth

struct Constants {
    static let serviceID = CBUUID(string:"12E61727-B41A-436F-B64D-4777B35F2294")
    static let PSMID = CBUUID(string:CBUUIDL2CAPPSMCharacteristicString)
}
