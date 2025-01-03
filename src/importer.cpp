/*********************************************************************************************************************************************/
/*  DocWire SDK: Award-winning modern data processing in C++20. SourceForge Community Choice & Microsoft support. AI-driven processing.      */
/*  Supports nearly 100 data formats, including email boxes and OCR. Boost efficiency in text extraction, web data extraction, data mining,  */
/*  document analysis. Offline processing possible for security and confidentiality                                                          */
/*                                                                                                                                           */
/*  Copyright (c) SILVERCODERS Ltd, http://silvercoders.com                                                                                  */
/*  Project homepage: https://github.com/docwire/docwire                                                                                     */
/*                                                                                                                                           */
/*  SPDX-License-Identifier: GPL-2.0-only OR LicenseRef-DocWire-Commercial                                                                   */
/*********************************************************************************************************************************************/

#include "importer.h"

#include "error_tags.h"
#include <filesystem>
#include "throw_if.h"

namespace docwire
{

template<>
struct pimpl_impl<Importer> : with_pimpl_owner<Importer>
{
  pimpl_impl(const ParserParameters &parameters)
    : m_parameters(parameters)
  {}

  bool
  isReadable(const std::filesystem::path& p) const
  {
    std::error_code ec;
    auto perms = std::filesystem::status(p, ec).permissions();
    if ((perms & std::filesystem::perms::owner_read) != std::filesystem::perms::none &&
        (perms & std::filesystem::perms::group_read) != std::filesystem::perms::none &&
        (perms & std::filesystem::perms::others_read) != std::filesystem::perms::none
            )
    {
      return true;
    }
    return false;
  }

  std::unique_ptr<ParserBuilder> findParser(data_source& data) const
  {
    std::optional<mime_type> mt = data.highest_confidence_mime_type();
    throw_if(!mt, "Data source has no mime type", errors::uninterpretable_data{});
    throw_if(data.mime_type_confidence(mime_type { "application/encrypted" }) >= confidence::high, errors::file_encrypted{});
    std::unique_ptr<ParserBuilder> builder = owner().find_parser_by_mime_type(*mt);
    throw_if (!builder, "find_parser_by_mime_type() failed", 
      mt->v, data.highest_mime_type_confidence(), errors::uninterpretable_data{});
    return builder;
  }

  std::unique_ptr<docwire::Parser> build_parser(ParserBuilder& builder)
  {
    return builder
        .withParameters(m_parameters)
        .build();
  }

  ChainElement& get_root_element(ChainElement& elem)
  {
    if (elem.get_parent())
      return get_root_element(*elem.get_parent());
    else
      return elem;
  }

  void
  process(Info& info)
  {
    if (!std::holds_alternative<data_source>(info.tag))
    {
      owner().emit(info);
      return;
    }
    auto data = std::get<data_source>(info.tag);
    std::unique_ptr<ParserBuilder> builder = findParser(data);
    std::unique_ptr<docwire::Parser> parser = build_parser(*builder);
    auto parser_callback = [this](const Tag& tag)
    {
      Info info{tag};
      if (std::holds_alternative<data_source>(tag))
        get_root_element(owner()).process(info);
      else
        owner().emit(info);
      if (info.cancel)
        return Parser::parsing_continuation::stop;
      else if (info.skip)
        return Parser::parsing_continuation::skip;
      else
        return Parser::parsing_continuation::proceed;
    }; 
    try
    {
      (*parser)(data, parser_callback);
    }
    catch (const std::exception& ex)
    {
      std::throw_with_nested(make_error("Parsing failed"));
    }
  }

  void
  add_parameters(const ParserParameters &parameters)
  {
    m_parameters += parameters;
  }

  std::shared_ptr<ParserBuilder> m_parser_builder;

  ParserParameters m_parameters;
};

Importer::Importer(const ParserParameters &parameters)
  : with_pimpl<Importer>(parameters)
{
}

Importer::Importer(Importer&&) = default;

void
Importer::process(Info& info)
{
  impl().process(info);
}

void
Importer::add_parameters(const ParserParameters &parameters)
{
  impl().add_parameters(parameters);
}

} // namespace docwire
