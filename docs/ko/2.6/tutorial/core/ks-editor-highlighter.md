---
title: KonadoScript 에디터
order: 5
---

# Godot 내장 KonadoScript 에디터

Konado 플러그인을 활성화한 뒤 파일 시스템 독에서 `.ks` 파일을 두 번 클릭하면 하단의 `KonadoEdit` 패널에서 열립니다. 에디터는 원본 KonadoScript 파일을 직접 수정하고 저장할 때 Godot 재가져오기를 실행합니다.

## 편집 기능

- 여러 `.ks` 파일을 탭으로 편집하고 문서별 커서 위치와 저장되지 않은 상태 유지
- 복구 초안을 자동 저장하고 에디터나 플러그인이 중단된 뒤 다시 열 때 복구
- 외부 파일 변경을 감지하고 수정하지 않은 문서는 자동으로 다시 로드하며 충돌 시 사용자에게 확인
- 찾기, 바꾸기, 줄 이동 및 로컬 분기 심볼 탐색
- 명령문 목록에서 현재 지원하는 모든 KonadoScript 명령 삽입

## 하이라이트와 자동 완성

`KND_KsHighlighter`는 Godot의 `SyntaxHighlighter`를 기반으로 합니다. 하이라이트, 코드 자동 완성, 명령문 템플릿은 `KS_LanguageCatalog`를 공유하며 유효한 키워드는 파서의 `KS_Token.KEYWORDS`를 기준으로 합니다. 명령을 추가하거나 제거하면 자동화 테스트가 두 정의의 일치 여부를 확인합니다.

하이라이트 정규식은 처음 사용할 때 한 번만 컴파일되며 각 줄에는 색상이 바뀌는 위치만 기록됩니다. 편집하거나 스크롤할 때 정규식을 반복해서 컴파일하거나 문자마다 딕셔너리 항목을 만들지 않습니다.

기본 하이라이트 리소스 위치:

```text
res://addons/konado/editor/ks_editor/highlighter.tres
```

사용자 정의 에디터에서 하이라이터를 직접 생성할 수도 있습니다.

```gdscript
set_syntax_highlighter(KND_KsHighlighter.new())
```

## 실시간 진단

입력을 잠시 멈추면 런타임 `KND_Shot` 리소스를 생성하지 않고 어휘, 구문, 의미 분석을 실행합니다. 오류와 경고는 다음 위치에 함께 표시됩니다.

- 코드 줄의 거터 표시와 배경색
- 에디터 하단의 문제 목록

문제나 거터 표시를 클릭하면 관련 위치로 이동합니다. 저장할 때는 일반 Godot 가져오기도 실행되므로 실시간 진단이 최종 가져오기 결과를 대체하지는 않습니다.

## 단축키

| 작업 | Windows / Linux | macOS |
| --- | --- | --- |
| 저장 | `Ctrl+S` | `Command+S` |
| 현재 탭 닫기 | `Ctrl+W` | `Command+W` |
| 찾기 | `Ctrl+F` | `Command+F` |
| 찾기 및 바꾸기 | `Ctrl+H` | `Command+Option+F` |
| 줄 이동 | `Ctrl+L` | `Command+L` |
