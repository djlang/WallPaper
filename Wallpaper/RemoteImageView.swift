import SwiftUI
import AppKit

struct RemoteImageView: View {
    private let url: URL?
    private let placeholderSystemName: String
    private let contentMode: ContentMode

    @State private var image: Image?

    init(url: URL?, placeholderSystemName: String = "photo", contentMode: ContentMode = .fill) {
        self.url = url
        self.placeholderSystemName = placeholderSystemName
        self.contentMode = contentMode
    }

    var body: some View {
        ZStack {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: placeholderSystemName)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: url?.absoluteString) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else {
            image = nil
            return
        }

        do {
            let (data, response) = try await TrustedURLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let nsImage = NSImage(data: data) else {
                image = nil
                return
            }
            image = Image(nsImage: nsImage)
        } catch {
            image = nil
        }
    }
}
