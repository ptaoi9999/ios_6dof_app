# Third-Party Licenses and Framework Acknowledgements

## iOS 6DoF App

This application uses the following frameworks and tools.

---

## 1. Swift

- **License**: Apache License 2.0 with Runtime Library Exception
- **Source**: https://swift.org/LICENSE.txt
- **Copyright**: Copyright (c) 2014-present Apple Inc. and the Swift project authors

```
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
```

**Runtime Library Exception**: Compiled binary applications that use Swift standard
library runtime (swiftrt, swiftCore, etc.) are **exempt** from the attribution
requirements of Apache 2.0 Section 4(a), 4(b), and 4(d). No attribution is
required in the final binary or its documentation.

---

## 2. Apple System Frameworks

The following frameworks are proprietary to Apple Inc. and are governed by the
**Apple Developer Program License Agreement (ADPLA)**:

| Framework     | Purpose                                | Privacy Info.plist Key Required          |
|---------------|----------------------------------------|------------------------------------------|
| RealityKit    | 3D scene rendering (VR environment)    | —                                        |
| ARKit         | 6DoF camera tracking                   | `NSCameraUsageDescription` (required)    |
| Vision        | Hand pose detection & tracking         | `NSCameraUsageDescription` (required)    |
| CoreMotion    | Device motion sensor data              | `NSMotionUsageDescription` (recommended) |
| SwiftUI       | Declarative UI framework               | —                                        |
| UIKit         | UIView, UIViewRepresentable base       | —                                        |

**License reference**: https://developer.apple.com/support/terms/

**Summary**:
- Use of these frameworks requires acceptance of the Apple Developer Program License Agreement.
- Apple frameworks are licensed for use on Apple platforms only, under a limited,
  non-exclusive, non-transferable, non-sublicensable license.
- No separate attribution is required within the app's UI for Apple's own frameworks.
- Commercial use is permitted subject to ADPLA compliance.

---

## 3. App Icon

The application icon was generated using an AI image generation tool for the
purpose of this project. No third-party assets with conflicting licenses are included.

---

## Privacy Requirements

Per Apple's framework requirements, this app's `Info.plist` includes:

- **`NSCameraUsageDescription`**: Required for ARKit (6DoF tracking) and Vision
  (hand pose detection) which access the device camera.

> [!NOTE]
> This application does **not** use any open-source third-party libraries that
> require separate attribution. All dependencies are Apple-provided system frameworks
> or the Swift language itself.
