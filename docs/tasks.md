# 현재 작업

## 상태

- 공개 버전: [v0.1.0](https://github.com/logone72/ram-monitor/releases/tag/v0.1.0)
- 앱 구현·사용자 피드백 반영·로컬 DMG 설치 확인 완료
- [Release 검증](https://github.com/logone72/ram-monitor/actions/runs/36383422250)과 공개 DMG의 비인증 다운로드·체크섬·서명·Universal 아키텍처 검사 완료
- 공개 DMG의 실제 UI 실행·깨끗한 사용자 환경 최초 실행·Intel Mac 실기 검증은 미확인

## 남은 작업

- [ ] 공개 DMG를 깨끗한 사용자 환경에서 설치·실행하고 최초 실행 안내 확인
- [ ] Intel Mac에서 실제 실행 확인
- [ ] 별도 승인 후 `logone72/homebrew-tap` 생성 및 cask 게시
- [ ] 공개 Release DMG의 checksum으로 cask를 검사하고 Homebrew 설치·실행 확인

배포 절차와 Tap 산출물 기준은 [release.md](release.md), 회귀 검증 기준은 [quality.md](quality.md)를 따른다. GitHub Release 완료와 Tap 완료는 별도로 관리한다.

현재·남은 작업이 바뀌면 이 문서와 [index.md](index.md)의 요약을 함께 갱신한다. 완료된 상세 작업 기록은 Git 이력에서 확인한다.
