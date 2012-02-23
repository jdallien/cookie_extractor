cookie_extractor
----------------

Extract cookies from Firefox, Chrome or Chromium sqlite cookie stores into a wget-compatible cookies.txt file.

### Install ###

gem install cookie_extractor

### Usage ###

cookie_extractor /path/to/firefox/cookies.sqlite > cookies.txt

Typical locations for the cookies file on Linux are:

 * Firefox: ~/.mozilla/firefox/<profile directory>/cookies.sqlite
 * Chrome: ~/.config/google-chrome/Default/Cookies
 * Chromium: ~/.config/chromium/Default/Cookies

### License ###

Copyright (c) 2012 Jeff Dallien

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
