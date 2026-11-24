import SwiftUI

extension View {
    func projectDestinations(client: APIClient) -> some View {
        navigationDestination(for: ProjectRoute.self) { route in
            ProjectView(client: client, projectId: route.id)
        }
    }
}

struct AreasView: View {
    let client: APIClient
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List(AreaSlug.allCases) { area in
                NavigationLink(value: area) {
                    Label(area.name, systemImage: area.symbol)
                }
            }
            .navigationTitle("Bereiche")
            .navigationDestination(for: AreaSlug.self) { area in
                AreaView(client: client, area: area, path: $path)
            }
            .projectDestinations(client: client)
        }
    }
}
