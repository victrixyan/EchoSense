//
//  EchoSenseApp.swift
//  EchoSense
//
//  Created by Victrix Yan on 2026/2/23.
//

import SwiftUI

@main
struct EchoSenseApp: App {
    @StateObject private var viewModel = MainViewModel()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                MainView(viewModel: viewModel)
            }
        }
    }
}
