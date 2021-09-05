//
//  ContentView.swift
//  Example
//
//  Created by Eunchul Jeon on 2021/09/05.
//

import SwiftUI
import MetalCamera

struct ExampleView: View {
    var body: some View {
        NavigationView {
            List(Examples.allCases) { item in
                NavigationLink(destination: item.view) {
                    HStack {
                        Text("\(item.name)")
                        Spacer()
                    }
                }
            }
            .navigationTitle(MetalCamera.libraryName)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ExampleView()
    }
}
