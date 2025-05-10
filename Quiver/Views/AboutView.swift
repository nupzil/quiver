//
//  Created by Nupzil on 2025/4/30.
//
//  Copyright © 2025 Nupzil <vvgvjks@gmail.com>.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice
//  (including the next paragraph) shall be included in all copies or substantial
//  portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
//  ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
//  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
//  OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import SwiftUI

struct AboutView: View {
    let year = Calendar.current.component(.year, from: Date())
    

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSImage(named: "AppIcon")!)
                .resizable()
                .frame(width: 80, height: 80)
                .cornerRadius(20)
                .shadow(radius: 5)
            
            Text("\(AppInfo.appName)")
                .font(.system(size: 22, weight: .bold))
                .padding(.top, 5)
            
            Text("Version: \(AppInfo.version) (\(AppInfo.buildNumber))")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text("© \(String(year)) \(AppInfo.developerName). All rights reserved.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                
            
            HStack(spacing: 4) {
                Text("GitHub for \(AppInfo.appName): ")
                    .font(.system(size: 12))
                
                Link("\(AppInfo.repositoryURL)", destination: URL(string: AppInfo.repositoryURL)!)
                    .font(.system(size: 12))
            }
        }
        .frame(width: 450, height: 320)
        .background(Color(NSColor.windowBackgroundColor))
        .animation(.easeInOut, value: AppInfo.appName)
    }
}

#Preview {
    AboutView()
}
