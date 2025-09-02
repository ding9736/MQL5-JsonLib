//+------------------------------------------------------------------+
//| Core/JsonStreamParser.mqh                                        |
//+------------------------------------------------------------------+
#ifndef MQL5_JSON_STREAM_PARSER
#define MQL5_JSON_STREAM_PARSER

#include "JsonCore.mqh"
#include "JsonStream.mqh"
#include "JsonUtils.mqh"

namespace MQL5_Json
{

class JsonStreamParser
{
private:
   Internal::ICharacterStreamReader *m_reader;
   IJsonStreamHandler               *m_handler;
   JsonParseOptions                 m_options;
   uint                             m_depth;
   bool                             m_is_owner_of_reader;

   Internal::StringBuilder          m_reusable_sb;

   bool SetError(JsonError &error, const string &message, const string context = "");
   void SkipWhitespaceAndComments();
   bool ParseValue(JsonError &error);
   bool ParseObject(JsonError &error);
   bool ParseArray(JsonError &error);
   bool ParseString(string &out_str, JsonError &error);
   bool ParseNumber(JsonError &error);
   bool ParseKeyword(JsonError &error);

   bool ExpectSequence(const string &sequence, JsonError &error);

public:
   JsonStreamParser();
   ~JsonStreamParser();

   bool Parse(Internal::ICharacterStreamReader *reader, IJsonStreamHandler *handler, JsonError &error, const JsonParseOptions &options, bool take_ownership);
};


JsonStreamParser::JsonStreamParser():m_reader(NULL),m_handler(NULL),m_depth(0),m_is_owner_of_reader(false),m_reusable_sb(1024) {}
JsonStreamParser::~JsonStreamParser()
{
   if(m_is_owner_of_reader && CheckPointer(m_reader) == POINTER_DYNAMIC)
   {
      delete m_reader;
      m_reader = NULL;
   }
}

bool JsonStreamParser::Parse(Internal::ICharacterStreamReader*r,IJsonStreamHandler*h,JsonError &e,const JsonParseOptions &o,bool own)
{
   e.Clear();
   if(CheckPointer(r)==POINTER_INVALID || CheckPointer(h)==POINTER_INVALID)
   {
      e.message = "Invalid reader or handler provided.";
      if (own && CheckPointer(r) != POINTER_INVALID) delete r;
      return false;
   }
   m_reader = r;
   m_handler = h;
   m_options = o;
   m_depth = 0;
   m_is_owner_of_reader = own;
   if(!m_handler.OnStartDocument())
   {
      SetError(e,"Handler aborted parsing at start");
      if (own && m_reader != NULL)
      {
         delete m_reader;
         m_reader = NULL;
      }
      return false;
   }
   SkipWhitespaceAndComments();
   if(m_reader.IsEOF())
   {
      m_handler.OnEndDocument();
      return true;
   }
   if(!ParseValue(e))
   {
      if (own && m_reader != NULL)
      {
         delete m_reader;
         m_reader = NULL;
      }
      return false;
   }
   SkipWhitespaceAndComments();
   if(!m_reader.IsEOF())
   {
      SetError(e,"Extra content found after JSON value");
      if (own && m_reader != NULL)
      {
         delete m_reader;
         m_reader = NULL;
      }
      return false;
   }
   return m_handler.OnEndDocument();
}

bool JsonStreamParser::SetError(JsonError &e,const string &m,const string c)
{
   if(e.message == "")
   {
      if(CheckPointer(m_reader) != POINTER_INVALID)
      {
         e.line = m_reader.Line();
         e.column = m_reader.Column();
         e.context = c != "" ? c : m_reader.GetContext(20);
      }
      e.message = m;
   }
   return false;
}

void JsonStreamParser::SkipWhitespaceAndComments()
{
   while(!m_reader.IsEOF())
   {
      ushort c = m_reader.Peek();
      if(c == ' ' || c == '\r' || c == '\n' || c == '\t')
      {
         m_reader.Next();
         continue;
      }
      if(m_options.allow_comments && c == '/')
      {
         m_reader.Next();
         ushort next_c = m_reader.Peek();
         if(next_c == '/')
         {
            while(!m_reader.IsEOF() && m_reader.Next() != '\n');
            continue;
         }
         else if(next_c == '*')
         {
            m_reader.Next();
            while(!m_reader.IsEOF())
            {
               if(m_reader.Next()=='*' && m_reader.Peek()=='/')
               {
                  m_reader.Next();
                  break;
               }
            }
            continue;
         }
         else
         {
            m_reader.Prev();
         }
      }
      break;
   }
}

bool JsonStreamParser::ParseValue(JsonError &e)
{
   if(m_depth>=m_options.max_depth) return SetError(e,"Max depth exceeded");
   SkipWhitespaceAndComments();
   if(m_reader.IsEOF()) return SetError(e,"Unexpected end of input, expected a value");
   ushort c=m_reader.Peek();
   switch(c)
   {
   case '{':
      m_depth++;
      return ParseObject(e);
   case '[':
      m_depth++;
      return ParseArray(e);
   case '"':
   {
      string s;
      if(!ParseString(s, e)) return false;
      return m_handler.OnString(s);
   }
   case 't':
   case 'f':
   case 'n':
      return ParseKeyword(e);
   default:
      if(c=='-' || (c>='0' && c<='9')) return ParseNumber(e);
   }
   string error_msg = "Invalid character '" + ShortToString(c) + "' starting a value";
   return SetError(e, error_msg);
}

bool JsonStreamParser::ParseObject(JsonError &e)
{
   m_reader.Next();
   if(!m_handler.OnStartObject())
   {
      m_depth--;
      return SetError(e, "Handler aborted at start of object");
   }
   SkipWhitespaceAndComments();
   if(m_reader.Peek() == '}')
   {
      m_reader.Next();
      m_depth--;
      return m_handler.OnEndObject();
   }
   while(true)
   {
      if(m_reader.Peek() != '"')
      {
         m_depth--;
         return SetError(e, "Expected string key in object");
      }
      string key;
      if(!ParseString(key, e))
      {
         m_depth--;
         return false;
      }
      if(!m_handler.OnKey(key))
      {
         m_depth--;
         return SetError(e, "Handler aborted at object key");
      }
      SkipWhitespaceAndComments();
      if(m_reader.Next() != ':')
      {
         m_depth--;
         return SetError(e, "Expected ':' after key in object");
      }
      if(!ParseValue(e))
      {
         m_depth--;
         return false;
      }
      SkipWhitespaceAndComments();
      ushort c = m_reader.Peek();
      if(c == '}')
      {
         m_reader.Next();
         m_depth--;
         return m_handler.OnEndObject();
      }
      if(c != ',')
      {
         m_depth--;
         return SetError(e, "Expected ',' or '}' in object");
      }
      m_reader.Next();
      SkipWhitespaceAndComments();
      if(m_options.allow_trailing_commas && m_reader.Peek() == '}')
      {
         m_reader.Next();
         m_depth--;
         return m_handler.OnEndObject();
      }
   }
}

bool JsonStreamParser::ParseArray(JsonError &e)
{
   m_reader.Next();
   if(!m_handler.OnStartArray())
   {
      m_depth--;
      return SetError(e,"Handler aborted at start of array");
   }
   SkipWhitespaceAndComments();
   if(m_reader.Peek() == ']')
   {
      m_reader.Next();
      m_depth--;
      return m_handler.OnEndArray();
   }
   while(true)
   {
      if(!ParseValue(e))
      {
         m_depth--;
         return false;
      }
      SkipWhitespaceAndComments();
      ushort c = m_reader.Peek();
      if(c == ']')
      {
         m_reader.Next();
         m_depth--;
         return m_handler.OnEndArray();
      }
      if(c != ',')
      {
         m_depth--;
         return SetError(e,"Expected ',' or ']' in array");
      }
      m_reader.Next();
      SkipWhitespaceAndComments();
      if(m_options.allow_trailing_commas && m_reader.Peek() == ']')
      {
         m_reader.Next();
         m_depth--;
         return m_handler.OnEndArray();
      }
   }
}

bool JsonStreamParser::ParseString(string &s, JsonError &e)
{
   m_reusable_sb.Clear();
   m_reader.Next();
   while(true)
   {
      if(m_reader.IsEOF()) return SetError(e, "Unterminated string");
      ushort c = m_reader.Next();
      if(c=='"')
      {
         s = m_reusable_sb.ToString();
         return true;
      }
      if(c=='\\')
      {
         if(m_reader.IsEOF()) return SetError(e, "Unterminated string (ends with escape char)");
         c=m_reader.Next();
         switch(c)
         {
         case '"':
         case '\\':
         case '/':
            m_reusable_sb.AppendChar(c);
            break;
         case 'b':
            m_reusable_sb.AppendChar((ushort)8);
            break;
         case 'f':
            m_reusable_sb.AppendChar((ushort)12);
            break;
         case 'n':
            m_reusable_sb.AppendChar((ushort)'\n');
            break;
         case 'r':
            m_reusable_sb.AppendChar((ushort)'\r');
            break;
         case 't':
            m_reusable_sb.AppendChar((ushort)'\t');
            break;
         case 'u':
         {
            uint unicode_val = 0;
            for(int i = 0; i < 4; i++)
            {
               if(m_reader.IsEOF()) return SetError(e, "Unterminated string (in unicode escape)");
               ushort hex_char = m_reader.Next();
               unicode_val <<= 4;
               if(hex_char >= '0' && hex_char <= '9') unicode_val += (hex_char - '0');
               else if(hex_char >= 'a' && hex_char <= 'f') unicode_val += (hex_char - 'a' + 10);
               else if(hex_char >= 'A' && hex_char <= 'F') unicode_val += (hex_char - 'A' + 10);
               else return SetError(e, "Invalid hex character in unicode escape");
            }
            m_reusable_sb.AppendChar((ushort)unicode_val);
            break;
         }
         default:
         {
            string error_msg = "Invalid escape sequence '\\" + ShortToString(c) + "'";
            return SetError(e, error_msg);
         }
         }
      }
      else
      {
         if(c<32 && m_options.strict_unicode) return SetError(e,"Unescaped control character in string");
         m_reusable_sb.AppendChar(c);
      }
   }
}

bool JsonStreamParser::ParseNumber(JsonError &e)
{
   m_reusable_sb.Clear();
   ENUM_JSON_TYPE t=JSON_INT;
   if(m_reader.Peek() == '-') m_reusable_sb.AppendChar(m_reader.Next());
   while(!m_reader.IsEOF() && m_reader.Peek() >= '0' && m_reader.Peek() <= '9') m_reusable_sb.AppendChar(m_reader.Next());
   if(!m_reader.IsEOF() && m_reader.Peek() == '.')
   {
      t = JSON_DOUBLE;
      m_reusable_sb.AppendChar(m_reader.Next());
      while(!m_reader.IsEOF() && m_reader.Peek() >= '0' && m_reader.Peek() <= '9') m_reusable_sb.AppendChar(m_reader.Next());
   }
   if(!m_reader.IsEOF() && (m_reader.Peek() == 'e' || m_reader.Peek() == 'E'))
   {
      t = JSON_DOUBLE;
      m_reusable_sb.AppendChar(m_reader.Next());
      if(!m_reader.IsEOF() && (m_reader.Peek() == '+' || m_reader.Peek() == '-')) m_reusable_sb.AppendChar(m_reader.Next());
      while(!m_reader.IsEOF() && m_reader.Peek() >= '0' && m_reader.Peek() <= '9') m_reusable_sb.AppendChar(m_reader.Next());
   }
   string ns = m_reusable_sb.ToString();
   if(StringLen(ns)==0 || ns=="-" || ns==".") return SetError(e,"Invalid number format");
   return m_handler.OnNumber(ns,t);
}

bool JsonStreamParser::ExpectSequence(const string &sequence, JsonError &error)
{
   for(int i = 0; i < StringLen(sequence); i++)
   {
      if(m_reader.IsEOF() || m_reader.Next() != (ushort)StringGetCharacter(sequence, i))
      {
         string error_msg = "Invalid keyword syntax, expected '" + sequence + "'";
         return SetError(error, error_msg);
      }
   }
   return true;
}

bool JsonStreamParser::ParseKeyword(JsonError &e)
{
   ushort c = m_reader.Peek();
   switch(c)
   {
   case 't':
      m_reader.Next();
      if(!ExpectSequence("rue", e)) return false;
      return m_handler.OnBool(true);
   case 'f':
      m_reader.Next();
      if(!ExpectSequence("alse", e)) return false;
      return m_handler.OnBool(false);
   case 'n':
      m_reader.Next();
      if(!ExpectSequence("ull", e)) return false;
      return m_handler.OnNull();
   }
   return SetError(e, "Invalid keyword");
}

}
#endif // MQL5_JSON_STREAM_PARSER

