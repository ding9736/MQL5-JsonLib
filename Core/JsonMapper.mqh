//+------------------------------------------------------------------+
//| Core/JsonMapper.mqh                                              |
//+------------------------------------------------------------------+
#ifndef MQL5_JSON_MAPPER
#define MQL5_JSON_MAPPER

#include "JsonCore.mqh"
#include "JsonNode.mqh"
#include "JsonDocument.mqh"

namespace MQL5_Json
{

class JsonMapper
{
public:
   static bool Deserialize(const JsonNode &node, IJsonSerializable &target_object)
   {
      if(!node.IsValid())
      {
         return false;
      }
      target_object.FromJson(node);
      return true;
   }

   static bool Serialize(const IJsonSerializable &source_object, JsonDocument &target_doc)
   {
      source_object.ToJson(target_doc);
      return target_doc.IsValid();
   }
};
}

#endif // MQL5_JSON_MAPPER

