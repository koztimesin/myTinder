//
//  ChatViewModel.swift
//  myTinder
//
//  Created by Ismail on 29.10.2026.
//

import Foundation
import Observation
import SwiftUI

/// Состояние экрана чата.
enum ChatScreenState: Equatable {
    /// Первая загрузка идёт.
    case loading
    /// Первая загрузка не удалась.
    case failed
    /// История загружена (может быть пустой).
    case content
}

/// Статус доставки сообщения.
enum MessageDelivery: Equatable {
    /// Сервер принял сообщение.
    case sent
    /// Отправляется.
    case sending
    /// Отправить не удалось.
    case failed
}

/// Сообщение вместе со статусом доставки.
struct ChatEntry: Identifiable, Equatable {
    /// Само сообщение.
    var message: Message
    /// Статус доставки.
    var delivery: MessageDelivery

    var id: UUID { message.id }
}

/// Строка списка чата.
enum ChatRowViewModel: Identifiable {
    /// Разделитель дня.
    case daySeparator(DaySeparatorViewModel)
    /// Сообщение.
    case message(MessageBubbleViewModel)

    var id: String {
        switch self {
        case .daySeparator(let model): model.id
        case .message(let model): model.id.uuidString
        }
    }
}

@MainActor
@Observable
final class ChatViewModel {

    /// Размер страницы истории.
    private let pageSize = 50
    /// Максимальная длина сообщения (совпадает с ограничением в БД).
    private let maxBodyLength = 2000

    private let matchID: UUID
    private let partner: MatchPartner
    private let currentUserID: UUID
    private let repository: ChatRepositoryProtocol
    private let photoURLProvider: PhotoURLProviderProtocol
    private let onRead: @MainActor () -> Void

    /// Сообщения в порядке времени.
    private var entries: [ChatEntry] = []
    private var partnerPhotoURL: URL?
    private var draft = ""
    private var hasLoaded = false
    private var loadFailed = false
    private var isLoadingOlder = false
    private var isForeground = true
    /// Нужно ли отметить диалог прочитанным (при открытии и при новых сообщениях собеседника).
    private var needsMarkRead = true
    /// Есть ли более старые сообщения на сервере.
    private(set) var hasMoreHistory = false

    /// - Parameters:
    ///   - matchID: матч этого диалога.
    ///   - partner: собеседник.
    ///   - currentUserID: id текущего пользователя.
    ///   - repository: источник сообщений.
    ///   - photoURLProvider: выдача ссылок на фото.
    ///   - onRead: вызывается после того, как диалог отмечен прочитанным (обновить список матчей).
    init(
        matchID: UUID,
        partner: MatchPartner,
        currentUserID: UUID,
        repository: ChatRepositoryProtocol,
        photoURLProvider: PhotoURLProviderProtocol,
        onRead: @escaping @MainActor () -> Void
    ) {
        self.matchID = matchID
        self.partner = partner
        self.currentUserID = currentUserID
        self.repository = repository
        self.photoURLProvider = photoURLProvider
        self.onRead = onRead
    }

    // MARK: - Загрузка и слияние

    /// Загружает последнюю страницу и сливает её с тем, что уже есть.
    private func loadLatest() async {
        do {
            let page = try await repository.fetchMessages(matchID: matchID, before: nil, limit: pageSize)
            if !hasLoaded {
                hasMoreHistory = page.count == pageSize
            }
            merge(page)
            hasLoaded = true
            loadFailed = false
            await markReadIfNeeded()
        } catch {
            guard !Task.isCancelled else { return }

            if !hasLoaded {
                loadFailed = true
            }
        }
    }

    /// Добавляет или обновляет сообщения по `id`; серверная версия заменяет локальную.
    /// - Parameter messages: сообщения с сервера.
    private func merge(_ messages: [Message]) {
        for message in messages {
            if let index = entries.firstIndex(where: { $0.id == message.id }) {
                entries[index] = ChatEntry(message: message, delivery: .sent)
            } else {
                entries.append(ChatEntry(message: message, delivery: .sent))
                if message.senderID != currentUserID {
                    needsMarkRead = true
                }
            }
        }
        entries.sort {
            ($0.message.sentAt, $0.id.uuidString) < ($1.message.sentAt, $1.id.uuidString)
        }
    }

    /// Обрабатывает сообщение из realtime.
    /// - Parameter message: новое сообщение.
    private func receive(_ message: Message) {
        merge([message])
        if message.senderID != currentUserID {
            Task { await markReadIfNeeded() }
        }
    }

    /// Отмечает диалог прочитанным, если это нужно и приложение на переднем плане.
    private func markReadIfNeeded() async {
        guard isForeground, needsMarkRead else { return }

        needsMarkRead = false
        do {
            try await repository.markRead(matchID: matchID)
            onRead()
        } catch {
            needsMarkRead = true
        }
    }

    // MARK: - Отправка

    /// Добавляет сообщение в список со статусом «отправляется» и запускает отправку.
    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        draft = ""
        let message = Message(id: UUID(), matchID: matchID, senderID: currentUserID, body: text, sentAt: Date())
        entries.append(ChatEntry(message: message, delivery: .sending))
        Task { await deliver(id: message.id) }
    }

    /// Отправляет сообщение и обновляет его статус.
    /// - Parameter id: идентификатор сообщения из списка.
    private func deliver(id: UUID) async {
        guard let entry = entries.first(where: { $0.id == id }) else { return }

        update(id: id, delivery: .sending)
        do {
            try await repository.send(id: id, matchID: matchID, body: entry.message.body)
            update(id: id, delivery: .sent)
        } catch {
            update(id: id, delivery: .failed)
        }
    }

    /// Меняет статус доставки сообщения.
    private func update(id: UUID, delivery: MessageDelivery) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }

        entries[index].delivery = delivery
    }

    /// Повторяет отправку не доставленного сообщения.
    private func retry(id: UUID) {
        Task { await deliver(id: id) }
    }

    /// Удаляет не доставленное сообщение из списка.
    private func discard(id: UUID) {
        entries.removeAll { $0.id == id && $0.delivery == .failed }
    }

    /// Обновляет черновик, обрезая его до допустимой длины.
    private func setDraft(_ value: String) {
        draft = String(value.prefix(maxBodyLength))
    }

    // MARK: - Строки списка

    /// Собирает модель пузыря сообщения.
    private func bubble(for entry: ChatEntry) -> MessageBubbleViewModel {
        let id = entry.id
        return MessageBubbleViewModel(
            id: id,
            text: entry.message.body,
            timeText: entry.message.sentAt.formatted(date: .omitted, time: .shortened),
            isFromMe: entry.message.senderID == currentUserID,
            delivery: entry.delivery,
            senderName: partner.name,
            onRetry: { [weak self] in self?.retry(id: id) },
            onDiscard: { [weak self] in self?.discard(id: id) }
        )
    }

    /// Заголовок разделителя дня: «Сегодня», «Вчера» или дата.
    private func dayTitle(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Сегодня" }
        if calendar.isDateInYesterday(day) { return "Вчера" }
        if calendar.isDate(day, equalTo: Date(), toGranularity: .year) {
            return day.formatted(.dateTime.day().month(.wide))
        }
        return day.formatted(.dateTime.day().month(.wide).year())
    }
}

extension ChatViewModel: ChatViewModelProtocol {

    var title: String { partner.name }

    var avatar: MatchAvatarViewModel {
        MatchAvatarViewModel(name: partner.name, photoURL: partnerPhotoURL, diameter: 32, showsRing: false)
    }

    var state: ChatScreenState {
        if hasLoaded { return .content }
        return loadFailed ? .failed : .loading
    }

    var rows: [ChatRowViewModel] {
        let calendar = Calendar.current
        var result: [ChatRowViewModel] = []
        var lastDay: Date?

        for entry in entries {
            let day = calendar.startOfDay(for: entry.message.sentAt)
            if day != lastDay {
                result.append(.daySeparator(DaySeparatorViewModel(
                    id: "day-\(day.timeIntervalSince1970)",
                    title: dayTitle(for: day)
                )))
                lastDay = day
            }
            result.append(.message(bubble(for: entry)))
        }
        return result
    }

    var lastRowID: String? {
        entries.last?.id.uuidString
    }

    var inputBar: ChatInputBarViewModel {
        ChatInputBarViewModel(
            text: Binding(get: { self.draft }, set: { self.setDraft($0) }),
            canSend: !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            onSend: { self.send() }
        )
    }

    func run() async {
        await loadLatest()

        while !Task.isCancelled {

            for await event in repository.events(matchID: matchID) {
                switch event {
                case .subscribed:
                    await loadLatest()
                case .message(let message):
                    receive(message)
                }
            }
            guard !Task.isCancelled else { return }

            try? await Task.sleep(for: .seconds(5))
        }
    }

    func retryLoad() async {
        loadFailed = false
        await loadLatest()
    }

    func loadOlder() async {
        guard hasLoaded, hasMoreHistory, !isLoadingOlder else { return }
        guard let oldest = entries.first(where: { $0.delivery == .sent })?.message.sentAt else { return }

        isLoadingOlder = true
        defer { isLoadingOlder = false }

        do {
            let page = try await repository.fetchMessages(matchID: matchID, before: oldest, limit: pageSize)
            merge(page)
            hasMoreHistory = page.count == pageSize
        } catch {
            // Страница не загрузилась: при следующей прокрутке к началу попробуем снова.
        }
    }

    func loadPhotos() async {
        guard let path = partner.photoPath else { return }

        let urls = await photoURLProvider.urls(for: [path])
        partnerPhotoURL = urls[path]
    }

    func sceneDidChange(isActive: Bool) async {
        isForeground = isActive
        guard isActive, hasLoaded else { return }

        await loadLatest()
        await markReadIfNeeded()
    }
}
