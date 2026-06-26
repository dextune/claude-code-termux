# Termux용 Claude Code 설치 도구

Android Termux `aarch64` 환경에서 공식 Claude Code Linux ARM64 릴리스를 설치하기 위한 스크립트입니다.

## 버전 상태

- 현재 완료된 대상 버전: `2.1.193`
- 설치 스크립트가 확인하는 공식 태그: `v2.1.193`
- 플랫폼 아티팩트: `linux-arm64`
- 이 저장소의 기본 문서와 기본 설치 버전: `2.1.193`

## 설치

Anthropic의 현재 Claude Code 안내처럼 npm 설치는 더 이상 권장하지 않습니다. Termux에서는 아래 원샷 설치 명령을 사용하세요.

```sh
curl -fsSL https://raw.githubusercontent.com/dextune/claude-code-termux/main/install-claude-code-termux.sh | sh
```

저장소를 이미 클론했다면 다음처럼 실행할 수 있습니다.

```sh
sh ./install-claude-code-termux.sh
```

설치 화면은 터미널 텍스트 그래픽과 단계 번호로 표시됩니다.

```text
+------------------------------------------------------------+
| Claude Code for Termux                                     |
| Secure installer for Android aarch64                       |
+------------------------------------------------------------+
| Target version : 2.1.193                                  |
| Platform       : linux-arm64                              |
| Install path   : .../versions/2.1.193                    |
| Launcher       : .../usr/bin/claude                       |
+------------------------------------------------------------+

[01/12] Installing required Termux packages
         done: Required Termux packages are installed.
```

설치가 끝나면 다음처럼 확인합니다.

```sh
command -v claude
claude --version
```

예상 결과:

```text
/data/data/com.termux/files/usr/bin/claude
2.1.193 (Claude Code)
```

## 삭제

Termux에서는 아래 원샷 삭제 명령을 사용하세요.

```sh
curl -fsSL https://raw.githubusercontent.com/dextune/claude-code-termux/main/uninstall-claude-code-termux.sh | sh
```

저장소를 이미 클론했다면 다음처럼 실행할 수 있습니다.

```sh
sh ./uninstall-claude-code-termux.sh
```

기본 삭제는 다음 항목을 제거합니다.

- `/data/data/com.termux/files/usr/bin/claude`
- `~/.local/share/claude/versions/2.1.193`
- `~/.local/share/claude/versions/2.1.193.pre-dns-patch`
- 관련 백업 파일
- 기존 npm 기반 `@anthropic-ai/claude-code` 패키지

기본 삭제는 사용자 설정을 보존합니다.

- `~/.claude`
- `~/.claude.json`

사용자 설정까지 제거하려면 다음처럼 실행합니다.

```sh
curl -fsSL https://raw.githubusercontent.com/dextune/claude-code-termux/main/uninstall-claude-code-termux.sh | REMOVE_USER_DATA=1 sh
```

저장소를 이미 클론했다면 다음처럼 실행할 수 있습니다.

```sh
REMOVE_USER_DATA=1 sh ./uninstall-claude-code-termux.sh
```

런처가 다른 방식으로 만들어진 파일처럼 보이면 기본 삭제는 보수적으로 건너뜁니다. 강제로 제거하려면 다음처럼 실행합니다.

```sh
curl -fsSL https://raw.githubusercontent.com/dextune/claude-code-termux/main/uninstall-claude-code-termux.sh | FORCE=1 sh
```

저장소를 이미 클론했다면 다음처럼 실행할 수 있습니다.

```sh
FORCE=1 sh ./uninstall-claude-code-termux.sh
```

## 설치 과정 요약

설치 스크립트는 다음 흐름으로 동작합니다.

1. Termux 필수 패키지를 설치합니다.
2. 기존 npm 기반 Claude Code 패키지를 제거합니다.
3. 공식 Anthropic GitHub 태그 `v2.1.193`을 확인합니다.
4. 공식 release manifest와 signature를 다운로드합니다.
5. Anthropic release signing key fingerprint를 확인합니다.
6. signed manifest를 검증합니다.
7. 공식 `linux-arm64` 바이너리를 다운로드합니다.
8. SHA256 checksum을 검증합니다.
9. ELF interpreter를 Termux glibc loader로 패치합니다.
10. DNS resolver 호환성 패치를 적용합니다.
11. `claude` launcher wrapper를 설치합니다.
12. `autoUpdates=false`를 설정합니다.
13. `claude --version`으로 `2.1.193` 설치를 검증합니다.

## 자동 업데이트 비활성화

설치 스크립트는 `~/.claude/settings.json`에 다음 값을 설정합니다.

```json
{
  "autoUpdates": false
}
```

Claude Code 자체 자동 업데이트가 패치되지 않은 Linux 바이너리로 교체할 수 있기 때문입니다. 이 Termux 설치 방식에서는 새 버전을 검증한 뒤 설치 스크립트로 업데이트하는 방식을 권장합니다.

## 자세한 패치 설명

기술적인 설치 및 패치 내용은 `INSTALLATION_DETAILS.md`와 `INSTALLATION_DETAILS_ko.md`를 참고하세요.
