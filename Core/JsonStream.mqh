//+------------------------------------------------------------------+
//| Core/JsonStream.mqh                                              |
//+------------------------------------------------------------------+
#ifndef MQL5_JSON_STREAM
#define MQL5_JSON_STREAM

#include "JsonCore.mqh"

namespace MQL5_Json
{
namespace Internal
{

class StringViewReader : public ICharacterStreamReader
{
private:
   string m_text;
   int    m_len, m_pos, m_line, m_col;

public:
   StringViewReader(const string &text): m_text(text), m_len(StringLen(text)), m_pos(0), m_line(1), m_col(1) {}

   bool IsValid() const override
   {
      return true;
   }

   bool   IsEOF() const override
   {
      return m_pos >= m_len;
   }
   int    Line() const override
   {
      return m_line;
   }
   int    Column() const override
   {
      return m_col;
   }
   ushort Peek() override
   {
      return IsEOF() ? 0 : StringGetCharacter(m_text, m_pos);
   }
   string GetContext(int size) const override
   {
      int s=MathMax(0, m_pos - size), e=MathMin(m_len, m_pos + size);
      string context_str = StringSubstr(m_text, s, e-s);
      StringReplace(context_str, "\n", "\\n");
      StringReplace(context_str, "\r", "\\r");
      StringReplace(context_str, "\t", "\\t");
      return context_str;
   }

   ushort Next() override
   {
      if(IsEOF()) return 0;
      ushort c = StringGetCharacter(m_text, m_pos++);
      if(c == '\n')
      {
         m_line++;
         m_col = 1;
      }
      else
      {
         m_col++;
      }
      return c;
   }

   bool Prev() override
   {
      if (m_pos > 0)
      {
         m_pos--;
         if(m_col > 1) m_col--;
         return true;
      }
      return false;
   }
};

class StringStreamReader : public ICharacterStreamReader
{
private:
   string m_text;
   int    m_len, m_pos, m_line, m_col;
   ushort m_utf16_buffer[];
public:
   StringStreamReader(const string &text): m_text(text), m_len(StringLen(text)), m_pos(0), m_line(1), m_col(1)
   {
      StringToShortArray(text, m_utf16_buffer);
   }

   bool IsValid() const override
   {
      return true;
   }

   bool   IsEOF() const override
   {
      return m_pos >= m_len;
   }
   int    Line() const override
   {
      return m_line;
   }
   int    Column() const override
   {
      return m_col;
   }
   ushort Peek() override
   {
      return IsEOF() ? 0 : m_utf16_buffer[m_pos];
   }
   string GetContext(int size) const override
   {
      int s=MathMax(0, m_pos - size), e=MathMin(m_len, m_pos + size);
      return StringSubstr(m_text, s, e-s);
   }

   ushort Next() override
   {
      if(IsEOF()) return 0;
      ushort c = m_utf16_buffer[m_pos++];
      if(c == '\n')
      {
         m_line++;
         m_col = 1;
      }
      else
      {
         m_col++;
      }
      return c;
   }

   bool Prev() override
   {
      if (m_pos > 0)
      {
         m_pos--;
         if(m_col > 1) m_col--;
         return true;
      }
      return false;
   }
};

class FileStreamReader : public ICharacterStreamReader
{
private:
   int   m_file_handle;
   uchar m_buffer[];
   int   m_buf_pos, m_buf_lim;
   int   m_line, m_col;
   bool  m_is_eof;
   ushort m_peek_char;
   bool  m_peek_char_valid;

   bool FillBuffer()
   {
      if(m_file_handle < 0 || m_is_eof) return false;
      int remaining = m_buf_lim - m_buf_pos;
      if(remaining > 0) ArrayCopy(m_buffer, m_buffer, 0, m_buf_pos, remaining);
      m_buf_pos = 0;
      m_buf_lim = remaining;
      int bytes_to_read = ArraySize(m_buffer) - m_buf_lim;
      if (bytes_to_read <= 0)
      {
         return false;
      }
      int bytes_read = (int)FileReadArray(m_file_handle, m_buffer, m_buf_lim, bytes_to_read);
      if(bytes_read <= 0)
      {
         m_is_eof = true;
         return m_buf_lim > 0;
      }
      m_buf_lim += bytes_read;
      return true;
   }

   ushort DecodeNextChar()
   {
      if (m_buf_pos >= m_buf_lim && !FillBuffer()) return 0;
      if (m_buf_pos >= m_buf_lim) return 0;
      uchar b1 = m_buffer[m_buf_pos++];
      ushort cp;
      if(b1 < 0x80)
      {
         cp = b1;
      }
      else if((b1 & 0xE0) == 0xC0)
      {
         if(m_buf_pos >= m_buf_lim && !FillBuffer()) return '?';
         uchar b2 = m_buffer[m_buf_pos++];
         if((b2 & 0xC0) != 0x80) return '?';
         cp = (ushort(b1 & 0x1F) << 6) | ushort(b2 & 0x3F);
      }
      else if((b1 & 0xF0) == 0xE0)
      {
         if((m_buf_pos + 1 >= m_buf_lim && !FillBuffer()) || (m_buf_pos + 1 >= m_buf_lim)) return '?';
         uchar b2 = m_buffer[m_buf_pos++], b3 = m_buffer[m_buf_pos++];
         if((b2 & 0xC0) != 0x80 || (b3 & 0xC0) != 0x80) return '?';
         cp = (ushort(b1 & 0x0F) << 12) | (ushort(b2 & 0x3F) << 6) | ushort(b3 & 0x3F);
      }
      else
      {
         cp = '?';
      }
      return cp;
   }

public:
   FileStreamReader(int handle, int buffer_size=65536) :
      m_file_handle(handle), m_buf_pos(0), m_buf_lim(0), m_line(1), m_col(1), m_is_eof(false), m_peek_char(0), m_peek_char_valid(false)
   {
      if(buffer_size <= 0) buffer_size = 65536;
      if(ArrayResize(m_buffer, buffer_size) != buffer_size) m_file_handle = -1;
      if(m_file_handle >= 0 && FillBuffer() && m_buf_lim >= 3 && m_buffer[0] == 0xEF && m_buffer[1] == 0xBB && m_buffer[2] == 0xBF)
      {
         m_buf_pos = 3;
      }
   }

   ~FileStreamReader()
   {
      if(m_file_handle >= 0)
      {
         FileClose(m_file_handle);
         m_file_handle = -1;
      }
   }

   bool IsValid() const override
   {
      return m_file_handle >= 0;
   }

   bool   IsEOF() const override
   {
      return !m_peek_char_valid && m_buf_pos >= m_buf_lim && m_is_eof;
   }
   int    Line() const override
   {
      return m_line;
   }
   int    Column() const override
   {
      return m_col;
   }
   string GetContext(int length) const override
   {
      return "Context unavailable for file stream";
   }

   ushort Peek() override
   {
      if(!m_peek_char_valid && !IsEOF())
      {
         m_peek_char = DecodeNextChar();
         m_peek_char_valid = (m_peek_char != 0);
      }
      return m_peek_char;
   }

   ushort Next() override
   {
      ushort c;
      if(m_peek_char_valid)
      {
         c = m_peek_char;
         m_peek_char_valid = false;
         m_peek_char = 0;
      }
      else
      {
         c = DecodeNextChar();
      }
      if(c == '\n')
      {
         m_line++;
         m_col = 1;
      }
      else if(c != 0)
      {
         m_col++;
      }
      return c;
   }

   bool Prev() override
   {
      return false;
   }
};

}
}
#endif //MQL5_JSON_STREAM 

