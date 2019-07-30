/*
 * Copyright (c) 2018-present, 美团点评
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

const express = require('express');
const bodyParser = require('body-parser');
const fs = require('fs');
const process = require('child_process');

const app = express();

app.use(bodyParser.raw({
  type: 'binary/octet-stream',
  limit: '10mb'
}));

app.get('/', (req, res) => {
  res.send('Hello World!');
});

app.post('/logupload', (req, res) => {
  console.log('Logan client upload log file');
  if (!req.body) {
    return res.sendStatus(400);
  }
  var filename = req.query.name;
  console.log(filename);
  var writeStram = fs.createWriteStream(filename);
  writeStram.write(req.body);
  writeStram.end();
  process.exec('python decode_mars_nocrypt_log_file.py');
  // haha
  res.json({ success: true });
});

app.listen(4000, () => console.log('Logan demo server listening on port 4000!'));