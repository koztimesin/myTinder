//
//  AppConfig.swift
//  myTinder
//
//  Created by Ismail on 16.10.2026.
//

import Foundation

enum AppConfig {
    
    static let supabaseURL: URL = {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: urlString)
        else {
            fatalError("SUPABASE_URL не задан в Secrets.xcconfig")
        }
        
        return url
    }()

    static let supabaseKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              !key.isEmpty
        else {
            fatalError("SUPABASE_PUBLISHABLE_KEY не задан")
        }
        
        return key
    }()
}
