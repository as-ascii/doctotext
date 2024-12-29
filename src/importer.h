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

#ifndef DOCWIRE_IMPORTER_H
#define DOCWIRE_IMPORTER_H

#include <memory>

#include "chain_element.h"
#include "parser.h"
#include "parser_builder.h"
#include "parser_parameters.h"
#include "defines.h"

namespace docwire
{

class DllExport Importer : public ChainElement, public with_pimpl<Importer>
{
public:
  /**
   * @param parameters parser parameters
   */
  explicit Importer(const ParserParameters &parameters = ParserParameters());

  Importer(Importer &&other);

  Importer& operator=(const Importer &&other);

  virtual ~Importer();

  bool is_leaf() const override
  {
    return false;
  }

  /**
   * @brief Sets new input stream to parse
   * @param input_stream new input stream to parse
   */
  void set_input_stream(std::istream &input_stream);

  /**
   * @brief Adds parser parameters.
   * @param parameters parser parameters
   */
  void add_parameters(const ParserParameters &parameters);

  virtual std::unique_ptr<ParserBuilder> find_parser_by_mime_type(const mime_type& mime) const = 0;

protected:
  /**
   * @brief Starts parsing process.
   */
  void process(Info& info) override;

private:
  using with_pimpl<Importer>::impl;
};

} // namespace docwire

#endif //DOCWIRE_IMPORTER_H
