# Assets

게임에 사용되는 모든 리소스 파일을 보관한다.

## 폴더 구조

```
assets/
├── backgrounds/        # 패널·씬 배경 이미지
│   ├── bridge_bg.png         ← 브릿지 배경 (AI 생성, 탑뷰 픽셀아트)
│   └── ...
├── sprites/
│   ├── characters/     # SD 파일럿 캐릭터 스프라이트
│   ├── machines/       # 머신/메카 스프라이트
│   └── ui/             # UI 아이콘, 버튼 장식 등
├── fonts/              # 커스텀 폰트 (.ttf / .otf)
└── audio/              # BGM, 효과음 (.ogg / .wav)
```

## 네이밍 규칙

| 종류 | 형식 | 예시 |
|---|---|---|
| 배경 | `{씬명}_bg.png` | `bridge_bg.png`, `clicker_bg.png` |
| 캐릭터 스프라이트 | `char_{이름}_{상태}.png` | `char_navi_idle.png` |
| 머신 | `machine_t{티어}.png` | `machine_t2.png` |
| UI 아이콘 | `icon_{이름}.png` | `icon_dispatch.png` |
