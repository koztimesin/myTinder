//
//  SwipeDTO.swift
//  myTinder
//
//  Created by Ismail on 26.10.2026.
//

import Foundation

/// Строка таблицы `swipes` для вставки.
struct SwipeDTO: Encodable, Sendable {
    /// Кто свайпает (должен совпадать с `auth.uid()`, иначе RLS отклонит).
    let swiper: UUID
    /// Кого свайпают.
    let target: UUID
    /// `true` — лайк, `false` — дизлайк.
    let liked: Bool
}

/// Параметры RPC `get_feed`.
struct GetFeedParams: Encodable, Sendable {
    /// Сколько анкет запросить.
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case limit = "p_limit"
    }
}
