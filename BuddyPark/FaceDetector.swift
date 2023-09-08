//
//  FaceDetector.swift
//  BuddyPark
//
//  Created by 黄鹏昊 on 2023/9/8.
//

import Foundation
import Vision
import UIKit

class FaceDetector {
    static let shared = FaceDetector()
    
    func detectFaceRect(in image: UIImage, completion: @escaping (CGRect?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNDetectFaceRectanglesRequest { (request, error) in
            if let error = error {
                print("Face detection error: \(error.localizedDescription)")
                completion(nil)
            } else if let results = request.results as? [VNFaceObservation], let firstFace = results.first {
                completion(firstFace.boundingBox)
            } else {
                completion(nil)
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform face detection: \(error)")
            completion(nil)
        }
    }
}
