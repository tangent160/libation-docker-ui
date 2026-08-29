# License

MIT License

Copyright (c) 2026 tangent160

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## Scope

This license covers the packaging in this repository only. The packaging is the
Dockerfile, the scripts, the configuration, and the templates.

Two parts of this project are not under the MIT license:

- Libation. The image downloads it at run time. The image does not redistribute
  it. Libation is GPL-3.0.
- The unraid icon in `unraid/`. It comes from the artwork of Libation, thus it
  stays GPL-3.0.

The container image also holds software from Debian, under other licenses. See
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
