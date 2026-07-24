# iOS 6DoF App

スマホVRゴーグル（Google Cardboard系など）を使用して、iPhone単体で6DoF体験、ハンドトラッキング、およびバーチャル空間の歩き回りを実現するiOSアプリです。

## 特徴
- **6DoF位置トラッキング**: ARKitを活用したスマホVRでの位置トラッキング
- **ハンドトラッキング**: Vision Frameworkを活用した手のアクション検出
- **3D表示**: RealityKit (RealityView) によるiOS 17+ 向けのモダンな3D描画

## 開発環境と動作要件
- **OS**: iOS 17.0以上
- **フレームワーク**: SwiftUI, RealityKit, ARKit, Vision
- **開発ツール**: SwiftPM & Xcode (GitHub Actions経由で自動ビルド)

## プロジェクト構成
プロジェクトはLinux環境で編集可能であり、GitHub Actionsでビルドできる構成をとっています。
- `ios_6dof_app/`: Swiftソースコードおよびアセット
- `ios_6dof_app.xcodeproj/`: Xcodeプロジェクトファイル
- `.github/workflows/`: 自動ビルド・パッケージング用のGitHub Actions

## ライセンス・配信
LiveContainer等での実行を想定し、GitHub Actionsでは署名なし（Unsigned）のIPAファイルをビルドします。
