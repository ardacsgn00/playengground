import 'dart:js_interop';

/// Mirrors `window.playEngTts` defined in web/index.html or initialized via JS.
extension type _PlayEngTts._(JSObject _) implements JSObject {
  external void speak(JSString text, [JSNumber? rate]);
  external void stop();
}

@JS('playEngTts')
external _PlayEngTts? get _playEngTts;

@JS('eval')
external JSAny? _jsEval(JSString code);

bool _initialized = false;

void _ensureInitialized() {
  if (_initialized && _playEngTts != null) return;
  _initialized = true;

  if (_playEngTts == null) {
    try {
      _jsEval(r'''
        (function() {
          var cachedEnglishVoice = null;

          function getVoicesSafe() {
            if (!window.speechSynthesis) return [];
            try {
              return window.speechSynthesis.getVoices() || [];
            } catch (e) {
              return [];
            }
          }

          function findBestEnglishVoice() {
            var voices = getVoicesSafe();
            if (!voices || voices.length === 0) return null;

            function isRobotic(name) {
              return name.indexOf('zira') !== -1 || name.indexOf('david') !== -1 || name.indexOf('mark') !== -1 || name.indexOf('desktop') !== -1;
            }

            // 1. Google US English (Chrome's clean, articulate natural voice)
            for (var i = 0; i < voices.length; i++) {
              var v = voices[i];
              var name = (v.name || '').toLowerCase();
              var lang = (v.lang || '').toLowerCase().replace(/_/g, '-');
              if (name.indexOf('google us english') !== -1 || (name.indexOf('google') !== -1 && lang === 'en-us')) {
                return v;
              }
            }

            // 2. Microsoft Natural Online voices (Edge / Windows neural natural voices)
            for (var i = 0; i < voices.length; i++) {
              var v = voices[i];
              var name = (v.name || '').toLowerCase();
              var lang = (v.lang || '').toLowerCase().replace(/_/g, '-');
              if (lang.indexOf('en') === 0 && (name.indexOf('natural') !== -1 || name.indexOf('online') !== -1 || name.indexOf('jenny') !== -1 || name.indexOf('aria') !== -1)) {
                return v;
              }
            }

            // 3. Apple natural voices (Safari / macOS / iOS)
            for (var i = 0; i < voices.length; i++) {
              var v = voices[i];
              var name = (v.name || '').toLowerCase();
              if (name.indexOf('samantha') !== -1 || name.indexOf('karen') !== -1 || name.indexOf('daniel') !== -1 || name.indexOf('moira') !== -1) {
                return v;
              }
            }

            // 4. Any other Google English voice (Google UK, Google Australia, etc.)
            for (var i = 0; i < voices.length; i++) {
              var v = voices[i];
              var name = (v.name || '').toLowerCase();
              var lang = (v.lang || '').toLowerCase().replace(/_/g, '-');
              if (lang.indexOf('en') === 0 && name.indexOf('google') !== -1) {
                return v;
              }
            }

            // 5. Standard non-robotic en-US or en-GB voices
            for (var i = 0; i < voices.length; i++) {
              var v = voices[i];
              var lang = (v.lang || '').toLowerCase().replace(/_/g, '-');
              var name = (v.name || '').toLowerCase();
              if ((lang === 'en-us' || lang === 'en-gb') && !isRobotic(name)) {
                return v;
              }
            }

            // 6. Any non-robotic English voice
            for (var i = 0; i < voices.length; i++) {
              var v = voices[i];
              var lang = (v.lang || '').toLowerCase().replace(/_/g, '-');
              var name = (v.name || '').toLowerCase();
              if (lang.indexOf('en') === 0 && !isRobotic(name)) {
                return v;
              }
            }

            // 7. Fallback en-US / en-GB
            for (var i = 0; i < voices.length; i++) {
              var v = voices[i];
              var lang = (v.lang || '').toLowerCase().replace(/_/g, '-');
              if (lang === 'en-us' || lang === 'en-gb' || lang === 'en-ca' || lang === 'en-au') {
                return v;
              }
            }

            // 8. Any voice starting with en
            for (var i = 0; i < voices.length; i++) {
              var v = voices[i];
              var lang = (v.lang || '').toLowerCase().replace(/_/g, '-');
              if (lang.indexOf('en') === 0) {
                return v;
              }
            }

            return null;
          }

          function ensureVoiceLoaded() {
            if (!cachedEnglishVoice) {
              cachedEnglishVoice = findBestEnglishVoice();
            }
            return cachedEnglishVoice;
          }

          if (window.speechSynthesis) {
            ensureVoiceLoaded();
            if (typeof window.speechSynthesis.onvoiceschanged !== 'undefined') {
              window.speechSynthesis.onvoiceschanged = function() {
                cachedEnglishVoice = findBestEnglishVoice();
              };
            }
            window.speechSynthesis.addEventListener('voiceschanged', function() {
              cachedEnglishVoice = findBestEnglishVoice();
            });
          }

          var speakTimer = null;

          window.playEngTts = {
            speak: function(text, rate) {
              if (!window.speechSynthesis || !text) return;
              if (speakTimer) {
                clearTimeout(speakTimer);
                speakTimer = null;
              }

              try {
                window.speechSynthesis.cancel();
              } catch (e) {}

              speakTimer = setTimeout(function() {
                speakTimer = null;
                try {
                  var u = new SpeechSynthesisUtterance(text);
                  u.lang = 'en-US';
                  u.rate = rate || 0.95;
                  u.pitch = 1.0;

                  var picked = ensureVoiceLoaded();
                  if (picked) {
                    u.voice = picked;
                    if (picked.lang) {
                      u.lang = picked.lang;
                    }
                  }

                  if (window.speechSynthesis.paused) {
                    window.speechSynthesis.resume();
                  }

                  window.speechSynthesis.speak(u);
                } catch (err) {
                  console.warn('TTS speak error:', err);
                }
              }, 30);
            },

            stop: function() {
              if (speakTimer) {
                clearTimeout(speakTimer);
                speakTimer = null;
              }
              try {
                if (window.speechSynthesis) window.speechSynthesis.cancel();
              } catch (e) {}
            }
          };
        })();
      '''.toJS);
    } catch (_) {}
  }
}

bool ttsWebSupported() {
  _ensureInitialized();
  return _playEngTts != null;
}

void ttsWebSpeak(String text, double rate) {
  _ensureInitialized();
  _playEngTts?.speak(text.toJS, rate.toJS);
}

void ttsWebStop() {
  _ensureInitialized();
  _playEngTts?.stop();
}
