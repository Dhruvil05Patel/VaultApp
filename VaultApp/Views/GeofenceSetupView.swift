import SwiftUI
import MapKit

struct GeofenceSetupView: View {

    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) private var dismiss

    var folder: VaultFolder
    @State private var geofenceName: String = ""
    @State private var radius: Double = 200
    @State private var capturedGeofence: Geofence? = nil
    @State private var isCapturing: Bool = false
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Location Lock for \"\(folder.name)\"")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding(.horizontal, 24).padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Map preview
                    if let geo = folder.geofence ?? capturedGeofence {
                        Map(position: $cameraPosition) {
                            Annotation(geo.name, coordinate: CLLocationCoordinate2D(
                                latitude: geo.latitude, longitude: geo.longitude)) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title).foregroundStyle(.red)
                            }
                            MapCircle(center: CLLocationCoordinate2D(
                                latitude: geo.latitude, longitude: geo.longitude),
                                      radius: geo.radiusMeters)
                            .foregroundStyle(.blue.opacity(0.2))
                            .stroke(.blue, lineWidth: 1)
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onAppear {
                            cameraPosition = .region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(
                                    latitude: geo.latitude, longitude: geo.longitude),
                                latitudinalMeters: geo.radiusMeters * 4,
                                longitudinalMeters: geo.radiusMeters * 4
                            ))
                        }
                    }

                    // Location permission check
                    if GeofenceService.shared.authorizationStatus == .notDetermined {
                        Button("Allow Location Access") {
                            GeofenceService.shared.requestPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    } else if GeofenceService.shared.authorizationStatus == .denied {
                        Label("Location access denied. Enable in System Settings → Privacy.", systemImage: "location.slash")
                            .font(.callout).foregroundStyle(.orange)
                    }

                    // Zone name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Zone Name").font(.caption).foregroundStyle(.secondary)
                        TextField("e.g. Office, Home", text: $geofenceName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Radius slider
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Radius").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(radius))m").font(.caption).foregroundStyle(.secondary)
                        }
                        Slider(value: $radius, in: 50...2000, step: 50)
                    }

                    // Capture button
                    Button {
                        isCapturing = true
                        Task {
                            capturedGeofence = await GeofenceService.shared.captureCurrentLocation(
                                name: geofenceName.isEmpty ? "My Zone" : geofenceName,
                                radius: radius
                            )
                            isCapturing = false
                        }
                    } label: {
                        if isCapturing {
                            HStack { ProgressView().controlSize(.small); Text("Getting location…") }
                        } else {
                            Label("Use Current Location as Zone Center", systemImage: "location.fill")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(GeofenceService.shared.currentLocation == nil || isCapturing)

                    if capturedGeofence != nil || folder.geofence != nil {
                        HStack {
                            Button("Remove Location Lock", role: .destructive) {
                                var updated = folder
                                updated.geofence = nil
                                vaultManager.updateFolder(updated)
                                dismiss()
                            }
                            .buttonStyle(.plain).foregroundStyle(.red)
                            Spacer()
                            Button("Save Zone") {
                                var geo = capturedGeofence ?? folder.geofence!
                                geo.name = geofenceName.isEmpty ? geo.name : geofenceName
                                geo.radiusMeters = radius
                                var updated = folder
                                updated.geofence = geo
                                vaultManager.updateFolder(updated)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(capturedGeofence == nil && folder.geofence == nil)
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 460, minHeight: 500)
        .onAppear { GeofenceService.shared.startMonitoring() }
    }
}
