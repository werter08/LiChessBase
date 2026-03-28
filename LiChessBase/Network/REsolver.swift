//
//  REsolver.swift
//  Academy
//
//  Created by Begench on 20.10.2025.
//

import Foundation
import Resolver

extension Resolver {
    static func setup() {
        register { MainRepo() }
    }
}
