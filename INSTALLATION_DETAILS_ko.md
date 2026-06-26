# 설치 상세 문서

이 문서는 `install-claude-code-termux.sh`가 공식 Claude Code 바이너리를 검증한 뒤 적용하는 Termux 호환성 패치를 설명합니다.

## 버전 상태

- 현재 완료된 대상 버전: `2.1.193`
- 설치 스크립트가 확인하는 공식 태그: `v2.1.193`
- 플랫폼 아티팩트: `linux-arm64`
- 실행 대상: Android Termux `aarch64`

## 범위

이 설치 방식은 Claude Code를 재빌드하지 않고 소스 코드를 수정하지 않습니다. 공식 signed release artifact를 다운로드하고 검증한 뒤, Termux 실행에 필요한 최소한의 바이너리 후처리만 수행합니다.

## 1. ELF interpreter 패치

공식 `linux-arm64` 바이너리는 일반 Linux glibc loader를 기대합니다.

```text
/lib/ld-linux-aarch64.so.1
```

Termux에는 이 경로가 없으므로 `patchelf-glibc`를 사용해 Termux glibc loader로 변경합니다.

```text
/data/data/com.termux/files/usr/glibc/lib/ld-linux-aarch64.so.1
```

이 작업은 ELF metadata를 수정하는 작업이며, 애플리케이션 로직을 바꾸는 작업이 아닙니다.

## 2. DNS resolver fd 패치

Claude Code 런타임은 다음 Linux 표준 resolver 파일을 참조할 수 있습니다.

```text
/etc/resolv.conf
/etc/hosts
```

Termux의 실제 파일 위치는 다음과 같습니다.

```text
/data/data/com.termux/files/usr/etc/resolv.conf
/data/data/com.termux/files/usr/etc/hosts
```

Android 환경에서는 `/etc/resolv.conf`가 없거나 일반 Linux와 다르게 동작할 수 있습니다. 이를 피하기 위해 바이너리 내부 문자열을 짧은 file descriptor path로 바꿉니다.

```text
/etc/resolv.conf -> /dev/fd/3
/etc/hosts       -> /dev/fd/4
```

남는 바이트는 NUL byte로 채웁니다.

## 3. Launcher wrapper

설치 스크립트는 다음 위치에 launcher를 만듭니다.

```text
/data/data/com.termux/files/usr/bin/claude
```

wrapper는 `LD_PRELOAD`와 `LD_LIBRARY_PATH`를 제거하고, Termux resolver 파일을 fd `3`, fd `4`로 연 뒤 패치된 Claude Code 바이너리를 실행합니다.

## 4. 자동 업데이트 비활성화

설치 스크립트는 다음 값을 설정합니다.

```json
{
  "autoUpdates": false
}
```

자동 업데이트가 실행되면 패치되지 않은 새 Linux 바이너리로 교체될 수 있기 때문에, 이 Termux 방식에서는 명시적인 버전 검증 후 설치 스크립트로 업데이트하는 것이 안전합니다.

## 5. 검증 항목

설치 스크립트는 다음을 확인합니다.

- 공식 GitHub 태그 `v2.1.193`
- 공식 README installer URL
- release signing key fingerprint
- signed release manifest
- signed manifest에 기록된 `linux-arm64` checksum
- 패치된 ELF interpreter
- `claude --version` 출력에 `2.1.193` 포함 여부

수동 확인:

```sh
command -v claude
claude --version
glibc-runner /data/data/com.termux/files/usr/glibc/bin/patchelf \
  --print-interpreter ~/.local/share/claude/versions/2.1.193
```

예상 결과:

```text
/data/data/com.termux/files/usr/bin/claude
2.1.193 (Claude Code)
/data/data/com.termux/files/usr/glibc/lib/ld-linux-aarch64.so.1
```
