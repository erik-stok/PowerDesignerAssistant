unit uShared;

interface

uses
  Messages;
  
const
  // These need to be unique, but there's no need to use RegisterWindowMessage
  // since it's going to be targetted at our own window anyways...
  KM_KEYDOWN    = WM_USER + $9997;
  KM_KEYREPEAT  = WM_USER + $9998;
  KM_KEYUP      = WM_USER + $9999;

  // These are used to send the state of the special keys. By multiplying each
  // previous value by 2 we get bit-compatible values...
  SK_CTRL       = 1;
  SK_ALT        = 2;
  SK_SHIFT      = 4;

implementation

end.
