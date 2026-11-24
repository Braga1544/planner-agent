import SwiftUI

func errorMessage(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
}

// don't show cancels as errors
func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || Task.isCancelled
}

struct ErrorText: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.callout)
            .foregroundStyle(.red)
    }
}
