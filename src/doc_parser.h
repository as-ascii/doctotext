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

#ifndef DOCWIRE_DOC_PARSER_H
#define DOCWIRE_DOC_PARSER_H

#include "parser.h"
#include <vector>

namespace docwire
{
	class Metadata;

class DllExport DOCParser : public Parser
{
	private:
		friend class TextHandler;
		friend class SubDocumentHandler;
		friend class TableHandler;

	public:
    	void parse(const data_source& data) override;
		Parser& withParameters(const ParserParameters &parameters) override;

		inline static const std::vector<mime_type> supported_mime_types = { mime_type{"application/msword"} };
};

} // namespace docwire

#endif
