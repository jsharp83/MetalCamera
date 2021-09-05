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
                NavigationLink(destination: ExampleChildView(example: item)) {
                    Text("\(item.name)")
                }
            }
            .navigationTitle(MetalCamera.libraryName)
        }
    }
}

struct ExampleChildView: View {
    let example: Examples
    
    var body: some View {
        Text("\(example.name)")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ExampleView()
    }
}
