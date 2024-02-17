import UIKit
import Vision
import CoreImage

func detectAndCropFaces(image: UIImage, completion: @escaping (UIImage) -> Void) {
    print("开始进行人脸检测")
    
    guard let ciImage = CIImage(image: image) else {
        print("无法创建 CIImage")
        return
    }

    let request = VNDetectFaceRectanglesRequest { request, error in
        if let error = error {
            print("人脸检测失败: \(error)")
            return
        }
        guard let results = request.results as? [VNFaceObservation], let firstFace = results.first else {
            print("未检测到人脸")
            return
        }

        print("检测到人脸，开始裁剪")
        let faceRect = firstFace.boundingBox
        let width = ciImage.extent.width
        let height = ciImage.extent.height

        let expansionFactor: CGFloat = 2  // 增加 100%

        // 调整边界框的大小
        let expandedWidth = faceRect.size.width * (1 + expansionFactor)
        let expandedHeight = faceRect.size.height * (1 + expansionFactor)

        // 调整边界框的位置
        let expandedX = faceRect.origin.x - faceRect.size.width * expansionFactor / 2
        let expandedY = faceRect.origin.y - faceRect.size.height * expansionFactor / 2

        // 创建新的边界框，并确保它不超出图像范围
        let newRect = CGRect(x: max(expandedX * width, 0),
                             y: max(expandedY * height, 0),
                             width: min(expandedWidth * width, ciImage.extent.width - max(expandedX * width, 0)),
                             height: min(expandedHeight * height, ciImage.extent.height - max(expandedY * height, 0)))

        print("完成边界框计算，裁剪图像")
        let croppedCIImage = ciImage.cropped(to: newRect)
        let context = CIContext(options: nil)
        if let croppedCGImage = context.createCGImage(croppedCIImage, from: croppedCIImage.extent) {
            let croppedUIImage = UIImage(cgImage: croppedCGImage)
            DispatchQueue.main.async {
                print("裁剪完成，返回处理后的图像")
                completion(croppedUIImage)
            }
        } else {
            print("裁剪失败")
        }
    }
    
#if targetEnvironment(simulator)
    request.usesCPUOnly = true
#endif

    let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
    do {
        try handler.perform([request])
    } catch {
        print("处理请求失败: \(error)")
    }
}
