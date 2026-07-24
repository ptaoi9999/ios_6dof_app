# ファイルツリー

```
ios_6dof_app/                         # プロジェクトルート
├── .github/
│   └── workflows/
│       └── build.yml                  # GitHub Actions: 署名なしIPAビルドワークフロー
├── ios_6dof_app/                      # Swiftソースコード & アセット
│   ├── App.swift                      # @main アプリエントリーポイント
│   ├── Types.swift                    # 共通型定義 (Eye enum など)
│   ├── ContentView.swift              # メインView: SBSステレオレイアウト & ARView管理
│   ├── ARTracker.swift                # ARKit 6DoFトラッキング / Vision ハンドトラッキング / 物理演算
│   ├── HandSkeleton.swift             # 手骨格の3Dビジュアライゼーション (21関節PBR球体+ボーン)
│   ├── RoomScene.swift                # VRChat Cozy Cabin風バーチャル空間 (PBR家具・暖炉・照明)
│   ├── SettingsPanel.swift            # 3D設定パネル (移動・指タッチ対応パススルーボタン)
│   ├── Info.plist                     # アプリ設定・権限宣言 (NSCameraUsageDescription)
│   └── Assets.xcassets/
│       ├── Contents.json              # アセットカタログルート定義
│       └── AppIcon.appiconset/
│           ├── Contents.json          # AppIconセット定義 (1024x1024 universal)
│           └── icon.png               # アプリアイコン (ネオンVRヘッドセットデザイン)
├── ios_6dof_app.xcodeproj/
│   └── project.pbxproj               # Xcodeプロジェクト定義 (Linux編集可能)
├── GEMINI.md                          # 開発ルール & ToDoリスト
├── LICENSES.md                        # ライセンス情報 (Swift・Apple Frameworks)
├── README.md                          # プロジェクト概要・ビルド方法
└── .gitignore                         # Gitの除外設定
```

## モジュール構成

| ファイル | 役割 |
|---|---|
| `App.swift` | SwiftUIアプリのライフサイクル管理 |
| `Types.swift` | `Eye` enum などの共有型定義 |
| `ContentView.swift` | 左右のARViewをHStackで並べるSBSステレオレイアウトの調整役 |
| `ARTracker.swift` | ARKit（位置・回転）・Vision（ハンドトラッキング）・ボール物理演算を一元管理 |
| `HandSkeleton.swift` | Visionの関節座標を21個のPBR球体とボーン円柱で3D描画する手のビジュアル |
| `RoomScene.swift` | 部屋の壁・床・家具・暖炉・照明などのRealityKitシーン構築 |
| `SettingsPanel.swift` | 3D設定パネルUI。ヘッダーの掴み移動、指タッチのボタン操作に対応 |
