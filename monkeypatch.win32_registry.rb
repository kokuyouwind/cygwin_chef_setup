begin
  Win32::Registry::Error.new(259)
rescue ArgumentError => e
  if e.message == "invalid byte sequence in UTF-8"
    class Win32::Registry::Error
      FormatMessageW = Kernel32.extern "int FormatMessageW(int, void *, int, int, void *, int, void *)", :stdcall
      def initialize(code)
        @code = code
        msg = "\0\0".force_encoding(Encoding::UTF_16LE) * 1024
        len = FormatMessageW.call(0x1200, 0, code, 0, msg, msg.size, 0)
        msg = msg[0, len].encode(Encoding.find(Encoding.locale_charmap))
        super msg.tr("\r".encode(msg.encoding), '').chomp
      end
    end
  else
    raise e
  end
end