# Piper App – License Information

## Overview

Piper is an iOS/macOS speech synthesis application, architected to separate GPLv3 and MIT code. This project contains **two independent modules**:

1. **Audio Unit Extension** – GPLv3 Licensed
2. **Main Application (UI Frontend)** – MIT Licensed

The modules communicate only via **XPC**, never link GPL libraries directly into the MIT app. This ensures GPLv3 compliance while keeping the main app under the permissive MIT license.

---

## 1. Audio Unit Extension (GPLv3)

The Audio Unit Extension links with the following **GPLv3 libraries**:

- [eSpeak-NG SPM](https://github.com/espeak-ng/espeak-ng-spm) – GNU General Public License v3, 29 June 2007
- [Piper GPL](https://github.com/OHF-Voice/piper1-gpl) – GNU General Public License v3, 29 June 2007

All code in the Audio Unit Extension, including any modifications to the above libraries, is licensed under **GPLv3**. The extension is a **standalone program** and may be distributed independently or as a plugin, provided GPLv3 requirements are met.

**Key points under GPLv3:**

- You may use, modify, and redistribute this module under GPLv3.
- Source code must remain available when distributing the Extension or derivatives.
- The Extension **cannot be sublicensed under proprietary terms**.

Full text of the license: [GNU GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html)

---

## 2. Main Application (MIT License)

The main application provides the user interface and communicates with the Audio Unit Extension **only via XPC**, without linking or including any GPLv3 code. This ensures the MIT license can safely apply to the main app.

Therefore, the main application is licensed under the **MIT License**:

MIT License
Copyright (c) 2026 Ihor Shevchuk
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

## 3. Important Notes

- The **Main Application** and **Audio Unit Extension** are **separate programs**. Communication occurs only via **XPC**, never linking GPL code. Distributing the Extension as a separate binary or plugin ensures GPLv3 obligations remain isolated from the MIT-licensed main app.
- The shared framework contains only original Swift types, constants, Codable structs, and utility code (e.g., Logger) used for XPC communication. It **does not include any GPLv3 code** and may be safely imported into both the MIT main application and the GPLv3 Audio Unit Extension.
- Users and developers must comply with GPLv3 when redistributing the Extension.
- Any modifications to the main application can be licensed freely (MIT or other), while modifications to the Extension remain under GPLv3.

---

## 4. References

- [eSpeak-NG SPM Repository](https://github.com/espeak-ng/espeak-ng-spm)
- [Piper GPL Repository](https://github.com/OHF-Voice/piper1-gpl)
- [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.en.html)
- [MIT License](https://opensource.org/licenses/MIT)

---

**Repository:** [https://github.com/piper-tts-apps/piper-app-apple](https://github.com/piper-tts-apps/piper-app-apple)