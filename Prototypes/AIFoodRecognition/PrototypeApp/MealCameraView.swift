#if canImport(UIKit)
import SwiftUI
import UIKit
import PhotosUI

struct MealCameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: MealCameraView
        init(parent: MealCameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                parent.onCancel()
                return
            }
            parent.onCapture(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.onCancel() }
    }
}

/// The system picker grants access only to the selected image.
struct MealPhotoLibraryView: UIViewControllerRepresentable {
    let onSelect: (UIImage) -> Void
    let onCancel: () -> Void
    let onFailure: () -> Void
    let onLoading: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .compatible
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    static func dismantleUIViewController(_ uiViewController: PHPickerViewController, coordinator: Coordinator) {
        coordinator.cancel()
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MealPhotoLibraryView
        var active = true
        private var loading = false
        private var loadProgress: Progress?
        init(parent: MealPhotoLibraryView) { self.parent = parent }

        func cancel() { active = false; loadProgress?.cancel() }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard active else { return }
            guard let provider = results.first?.itemProvider else { cancel(); parent.onCancel(); return }
            guard !loading else { return }
            guard provider.canLoadObject(ofClass: UIImage.self) else { parent.onFailure(); return }
            loading = true
            parent.onLoading()
            loadProgress = provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                DispatchQueue.main.async {
                    guard let self, self.active else { return }
                    self.active = false
                    if let image = object as? UIImage { self.parent.onSelect(image) }
                    else { self.parent.onFailure() }
                }
            }
        }
    }
}
#endif
