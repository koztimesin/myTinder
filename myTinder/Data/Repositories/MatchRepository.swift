//
//  MatchRepository.swift
//  myTinder
//
//  Created by Ismail on 28.10.2026.
//

import Foundation
import Supabase

/// Доступ к матчам.
protocol MatchRepositoryProtocol: Sendable {
    /// Загружает все матчи текущего пользователя.
    /// - Returns: матчи в порядке сервера: свежие по последнему сообщению (или по времени матча) выше.
    func fetchMatches() async throws -> [MatchSummary]
    
    /// Открывает подписку на появление новых матчей текущего пользователя.
    /// - Returns: поток идентификаторов новых матчей. Завершается при ошибке подключения
    ///   или когда потребитель перестаёт его читать (подписка при этом закрывается).
    func newMatchSignals() -> AsyncStream<UUID>
    
    /// Открывает подписку на новые сообщения во всех диалогах текущего пользователя.
    /// - Returns: поток сигналов; завершается при ошибке подключения или когда потребитель перестаёт его читать.
    func messageSignals() -> AsyncStream<Void>
}

struct SupabaseMatchRepository {
    
    let client: SupabaseClient
}

extension SupabaseMatchRepository: MatchRepositoryProtocol {
    
    func fetchMatches() async throws -> [MatchSummary] {
        let userID = try await client.auth.session.user.id
        let dtos: [MatchSummaryDTO] = try await client
            .rpc("get_matches")
            .execute()
            .value
        return dtos.map { $0.toDomain(currentUserID: userID) }
    }
    
    func newMatchSignals() -> AsyncStream<UUID> {
        
        AsyncStream { continuation in
            
            let task = Task {
                
                do {
                    let userID = try await client.auth.session.user.id.uuidString
                    let channel = client.realtimeV2.channel("matches-\(userID)")
                    // Пользователь в паре бывает и user_a, и user_b, а фильтр допускает одно условие.
                    let userA = channel.postgresChange(
                        InsertAction.self, schema: "public", table: "matches",
                        filter: "user_a=eq.\(userID)"
                    )
                    let userB = channel.postgresChange(
                        InsertAction.self, schema: "public", table: "matches",
                        filter: "user_b=eq.\(userID)"
                    )
                    await channel.subscribe()
                    
                    await withTaskGroup(of: Void.self) { group in
                        
                        for stream in [userA, userB] {
                            
                            group.addTask {
                                
                                for await action in stream {
                                    
                                    if let dto = try? action.decodeRecord(as: MatchInsertDTO.self, decoder: JSONDecoder()) {
                                        continuation.yield(dto.id)
                                    }
                                }
                            }
                        }
                    }
                    
                    await client.realtimeV2.removeChannel(channel)
                } catch {
                    // Не удалось получить сессию или подключиться: поток просто завершается.
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    func messageSignals() -> AsyncStream<Void> {
        
        AsyncStream { continuation in
            
            let task = Task {
                let topic = "messages-\(UUID().uuidString.prefix(8))"
                let channel = client.realtimeV2.channel(topic)
                let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "messages")
                await channel.subscribe()
                
                for await _ in inserts {
                    continuation.yield()
                }
                
                await client.realtimeV2.removeChannel(channel)
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
