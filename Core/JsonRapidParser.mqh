//+------------------------------------------------------------------+
//| Core/JsonRapidParser.mqh                                         |
//+------------------------------------------------------------------+
#ifndef MQL5_JSON_RAPID_PARSER
#define MQL5_JSON_RAPID_PARSER

#include "JsonCore.mqh"
#include "JsonUtils.mqh"

namespace MQL5_Json
{
namespace Internal
{

class CJsonRapidParser
{
private:
   string    m_text;
   int       m_text_len;
   int       m_pos;

   JsonToken m_tape[];
   int       m_tape_size;
   int       m_tape_capacity;

   uint      m_max_depth;
   int       m_line;
   int       m_col;

   void SetError(JsonError &e,const string msg)
   {
      if(e.message == "")
      {
         e.message = msg;
         e.line = m_line;
         e.column = m_col;
         e.context = StringSubstr(m_text, MathMax(0, m_pos - 15), 30);
      }
   }

   ushort NextChar(bool advance=true)
   {
      if (m_pos >= m_text_len) return 0;
      ushort c = StringGetCharacter(m_text, m_pos);
      if(advance)
      {
         m_pos++;
         if (c == '\n')
         {
            m_line++;
            m_col = 1;
         }
         else
         {
            m_col++;
         }
      }
      return c;
   }

   ushort PeekChar()
   {
      return (m_pos < m_text_len) ? StringGetCharacter(m_text, m_pos) : 0;
   }

   void Advance(int count)
   {
      for(int i=0; i<count; i++) NextChar();
   }

   void SkipWhitespace()
   {
      while(m_pos < m_text_len)
      {
         switch(StringGetCharacter(m_text, m_pos))
         {
         case ' ':
         case '\t':
         case '\n':
         case '\r':
            NextChar();
            break;
         default:
            return;
         }
      }
   }

   int AddToken()
   {
      if (m_tape_size >= m_tape_capacity)
      {
         int new_capacity = (m_tape_capacity > 0) ? m_tape_capacity * 2 : 256;
         if (ArrayResize(m_tape, new_capacity) < 0)
         {
            return -1;
         }
         m_tape_capacity = new_capacity;
      }
      return m_tape_size++;
   }

   bool ParseValue(int p_idx, uint d, JsonError &e);
   bool ParseObject(int p_idx, uint d, JsonError &e);
   bool ParseArray(int p_idx, uint d, JsonError &e);
   bool ParseString(int p_idx, JsonError &e);
   bool ParseNumber(int p_idx, JsonError &e);
   bool ParseLiteral(const string literal,ENUM_JSON_TYPE t,int p_idx,JsonError &e);

public:
   CJsonRapidParser() {}
   bool ParseToTape(const string &text, JsonToken &out_tape[], JsonError &error, const JsonParseOptions &options);
};


bool CJsonRapidParser::ParseToTape(const string &text, JsonToken &out_tape[], JsonError &error, const JsonParseOptions &options)
{
   m_pos = 0;
   m_line = 1;
   m_col = 1;
   m_text = text;
   m_text_len = StringLen(m_text);
   m_max_depth = options.max_depth;
   m_tape_size = 0;
   m_tape_capacity = MathMax(256, m_text_len / 7);
   ArrayFree(m_tape);
   if(ArrayResize(m_tape, m_tape_capacity) < 0)
   {
      SetError(error, "Initial tape allocation failed");
      return false;
   }
   ArrayFree(out_tape);
   if(m_text_len == 0)
   {
      return true;
   }
   if(!ParseValue(-1, 0, error))
   {
      return false;
   }
   SkipWhitespace();
   if(m_pos < m_text_len)
   {
      SetError(error, "Extra content after JSON value");
      return false;
   }
   if(m_tape_size > 0)
   {
      if(ArrayResize(out_tape, m_tape_size) < 0)
      {
         SetError(error, "Final tape allocation failed");
         return false;
      }
      ArrayCopy(out_tape, m_tape, 0, 0, m_tape_size);
   }
   return true;
}

bool CJsonRapidParser::ParseValue(int p_idx, uint d, JsonError &e)
{
   if(d > m_max_depth)
   {
      SetError(e, "Maximum JSON depth exceeded");
      return false;
   }
   SkipWhitespace();
   if(m_pos >= m_text_len)
   {
      SetError(e, "Unexpected end of input, expected a value");
      return false;
   }
   ushort c = PeekChar();
   switch(c)
   {
   case '{':
      return ParseObject(p_idx, d + 1, e);
   case '[':
      return ParseArray(p_idx, d + 1, e);
   case '"':
      return ParseString(p_idx, e);
   case 't':
      return ParseLiteral("true", JSON_BOOL, p_idx, e);
   case 'f':
      return ParseLiteral("false", JSON_BOOL, p_idx, e);
   case 'n':
      return ParseLiteral("null", JSON_NULL, p_idx, e);
   case '-':
   case '0':
   case '1':
   case '2':
   case '3':
   case '4':
   case '5':
   case '6':
   case '7':
   case '8':
   case '9':
      return ParseNumber(p_idx, e);
   }
   SetError(e, "Unexpected character '" + ShortToString(c) + "'");
   return false;
}

bool CJsonRapidParser::ParseString(int p_idx, JsonError &e)
{
   NextChar();
   int start_pos = m_pos;
   while(m_pos < m_text_len)
   {
      ushort c = PeekChar();
      if (c == '"')
      {
         int t_idx = AddToken();
         if(t_idx < 0)
         {
            SetError(e, "Tape allocation failed");
            return false;
         }
         m_tape[t_idx].type = JSON_STRING;
         m_tape[t_idx].start = start_pos;
         m_tape[t_idx].length = m_pos - start_pos;
         m_tape[t_idx].parent_index = p_idx;
         NextChar();
         return true;
      }
      if (c < 32)
      {
         SetError(e, "Unescaped control character in string");
         return false;
      }
      if (c == '\\')
      {
         NextChar();
         if (m_pos >= m_text_len)
         {
            break;
         }
         ushort escaped_char = PeekChar();
         switch(escaped_char)
         {
         case '"':
         case '\\':
         case '/':
         case 'b':
         case 'f':
         case 'n':
         case 'r':
         case 't':
            break;
         case 'u':
            NextChar();
            for(int i = 0; i < 4; i++)
            {
               if(m_pos >= m_text_len)
               {
                  SetError(e, "Incomplete unicode escape sequence");
                  return false;
               }
               ushort hex_char = PeekChar();
               if (!((hex_char >= '0' && hex_char <= '9') || (hex_char >= 'a' && hex_char <= 'f') || (hex_char >= 'A' && hex_char <= 'F')))
               {
                  SetError(e, "Invalid hex digit in unicode escape");
                  return false;
               }
               NextChar();
            }
            continue;
         default:
            SetError(e, "Invalid escape sequence '\\" + ShortToString(escaped_char) + "'");
            return false;
         }
      }
      NextChar();
   }
   SetError(e, "Unterminated string");
   return false;
}

bool CJsonRapidParser::ParseNumber(int p_idx, JsonError &e)
{
   int start = m_pos;
   if(PeekChar() == '-') NextChar();
   if (PeekChar() == '0')
   {
      NextChar();
      ushort c = PeekChar();
      if (c >= '0' && c <= '9')
      {
         SetError(e, "Invalid number: leading zero forbidden");
         return false;
      }
   }
   else
   {
      int digit_start = m_pos;
      while(PeekChar() >= '0' && PeekChar() <= '9') NextChar();
      if (m_pos == digit_start)
      {
         SetError(e, "Invalid number: missing digits");
         return false;
      }
   }
   if (PeekChar() == '.')
   {
      NextChar();
      int digit_start = m_pos;
      while(PeekChar() >= '0' && PeekChar() <= '9') NextChar();
      if (m_pos == digit_start)
      {
         SetError(e, "Invalid number: fraction requires digits");
         return false;
      }
   }
   if (PeekChar() == 'e' || PeekChar() == 'E')
   {
      NextChar();
      if (PeekChar() == '+' || PeekChar() == '-') NextChar();
      int digit_start = m_pos;
      while(PeekChar() >= '0' && PeekChar() <= '9') NextChar();
      if (m_pos == digit_start)
      {
         SetError(e, "Invalid number: exponent requires digits");
         return false;
      }
   }
   if(m_pos == start)
   {
      SetError(e, "Invalid number format");
      return false;
   }
   int t_idx = AddToken();
   if(t_idx < 0)
   {
      SetError(e, "Tape allocation failed");
      return false;
   }
   m_tape[t_idx].type = JSON_DOUBLE;
   m_tape[t_idx].start = start;
   m_tape[t_idx].length = m_pos - start;
   m_tape[t_idx].parent_index = p_idx;
   return true;
}

bool CJsonRapidParser::ParseObject(int p_idx, uint d, JsonError &e)
{
   NextChar();
   int token_idx = AddToken();
   if(token_idx < 0)
   {
      SetError(e, "Tape allocation failed");
      return false;
   }
   m_tape[token_idx].type = JSON_OBJECT;
   m_tape[token_idx].parent_index = p_idx;
   m_tape[token_idx].child_count = 0;
   SkipWhitespace();
   if (PeekChar() == '}')
   {
      NextChar();
      return true;
   }
   while(true)
   {
      SkipWhitespace();
      if (PeekChar() != '"')
      {
         SetError(e, "Expected string key");
         return false;
      }
      if (!ParseString(token_idx, e)) return false;
      SkipWhitespace();
      if (PeekChar() != ':')
      {
         SetError(e, "Expected ':' after key");
         return false;
      }
      NextChar();
      if (!ParseValue(token_idx, d, e)) return false;
      m_tape[token_idx].child_count++;
      SkipWhitespace();
      ushort c = PeekChar();
      if (c == '}')
      {
         NextChar();
         return true;
      }
      if (c != ',')
      {
         SetError(e, "Expected ',' or '}' in object");
         return false;
      }
      NextChar();
   }
}

bool CJsonRapidParser::ParseArray(int p_idx, uint d, JsonError &e)
{
   NextChar();
   int token_idx = AddToken();
   if(token_idx < 0)
   {
      SetError(e, "Tape allocation failed");
      return false;
   }
   m_tape[token_idx].type = JSON_ARRAY;
   m_tape[token_idx].parent_index = p_idx;
   m_tape[token_idx].child_count = 0;
   SkipWhitespace();
   if(PeekChar() == ']')
   {
      NextChar();
      return true;
   }
   while(true)
   {
      if (!ParseValue(token_idx, d, e)) return false;
      m_tape[token_idx].child_count++;
      SkipWhitespace();
      ushort c = PeekChar();
      if (c == ']')
      {
         NextChar();
         return true;
      }
      if (c != ',')
      {
         SetError(e, "Expected ',' or ']' in array");
         return false;
      }
      NextChar();
   }
}

bool CJsonRapidParser::ParseLiteral(const string literal, ENUM_JSON_TYPE t, int p_idx, JsonError &e)
{
   int len = StringLen(literal);
   if(m_text_len - m_pos < len)
   {
      SetError(e, "Unexpected end, expected '" + literal + "'");
      return false;
   }
   int current_pos = m_pos;
   for(int i = 0; i < len; i++)
   {
      if(StringGetCharacter(m_text, current_pos++) != StringGetCharacter(literal, i))
      {
         SetError(e, "Invalid literal, expected '" + literal + "'");
         return false;
      }
   }
   int t_idx = AddToken();
   if(t_idx < 0)
   {
      SetError(e, "Tape allocation failed");
      return false;
   }
   m_tape[t_idx].type = t;
   m_tape[t_idx].start = m_pos;
   m_tape[t_idx].length = len;
   m_tape[t_idx].parent_index = p_idx;
   Advance(len);
   return true;
}

}
}
#endif //MQL5_JSON_RAPID_PARSER

