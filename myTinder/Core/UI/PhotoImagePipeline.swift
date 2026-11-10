import SwiftUI
import UIKit

/// Общий кэш пользовательских фотографий. Ключ не содержит query signed URL,
/// поэтому обновление временной ссылки не заставляет повторно скачивать то же фото.
@MainActor
final class PhotoImagePipeline {

    static let shared = PhotoImagePipeline()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    init(session: URLSession = .shared) {
        self.session = session
        cache.countLimit = 80
        cache.totalCostLimit = 160 * 1_024 * 1_024
    }

    /// Синхронная проверка memory cache для первого кадра SwiftUI.
    /// Сеть здесь никогда не запускается.
    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: cacheKey(for: url) as NSString)
    }

    func image(for url: URL) async -> UIImage? {
        let key = cacheKey(for: url)
        if let cached = cachedImage(for: url) {
            return cached
        }
        if let task = inFlight[key] {
            return finish(await task.value, key: key)
        }

        let task = startLoading(url, key: key)
        return finish(await task.value, key: key)
    }

    func prefetch(_ urls: [URL]) async {
        let uniqueURLs = Array(Set(urls))
        for url in uniqueURLs {
            let key = cacheKey(for: url)
            if cache.object(forKey: key as NSString) == nil, inFlight[key] == nil {
                _ = startLoading(url, key: key)
            }
        }
        for url in uniqueURLs {
            _ = await image(for: url)
        }
    }

    func removeAll() {
        inFlight.values.forEach { $0.cancel() }
        inFlight.removeAll()
        cache.removeAllObjects()
    }

    private func cacheKey(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        components.query = nil
        components.fragment = nil
        return components.url?.absoluteString ?? url.path
    }

    @discardableResult
    private func startLoading(_ url: URL, key: String) -> Task<UIImage?, Never> {
        let session = session
        let task = Task<UIImage?, Never> { @concurrent in
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode)
                else { return nil }
                return UIImage(data: data)
            } catch {
                return nil
            }
        }
        inFlight[key] = task
        return task
    }

    private func finish(_ image: UIImage?, key: String) -> UIImage? {
        inFlight[key] = nil
        if let image {
            cache.setObject(image, forKey: key as NSString, cost: image.memoryCost)
        }
        return image
    }
}

private extension UIImage {
    var memoryCost: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

/// Показывает закэшированную фотографию и не убирает предыдущую, пока новая
/// полностью не загрузилась. Это исключает вспышку placeholder при листании.
struct CachedPhotoView<Placeholder: View>: View {

    let url: URL?
    private let placeholder: Placeholder
    @State private var image: UIImage?

    init(url: URL?, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder()
    }

    var body: some View {
        Group {
            if let displayedImage {
                Image(uiImage: displayedImage)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: url) {
            guard let url else {
                image = nil
                return
            }
            if let loaded = await PhotoImagePipeline.shared.image(for: url), !Task.isCancelled {
                image = loaded
            }
        }
    }

    /// `.task` выполняется после первого render pass, поэтому локальное состояние
    /// ещё может быть пустым. Синхронное чтение не даёт placeholder вспыхнуть,
    /// когда изображение уже находится в общем кэше.
    private var displayedImage: UIImage? {
        image ?? url.flatMap { PhotoImagePipeline.shared.cachedImage(for: $0) }
    }
}
