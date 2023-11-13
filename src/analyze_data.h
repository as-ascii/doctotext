/*********************************************************************************************************************************************/
/*  DocWire SDK: Award-winning modern data processing in C++17/20. SourceForge Community Choice & Microsoft support. AI-driven processing.   */
/*  Supports nearly 100 data formats, including email boxes and OCR. Boost efficiency in text extraction, web data extraction, data mining,  */
/*  document analysis. Offline processing possible for security and confidentiality                                                          */
/*                                                                                                                                           */
/*  Copyright (c) SILVERCODERS Ltd, http://silvercoders.com                                                                                  */
/*  Project homepage: https://github.com/docwire/docwire                                                                                     */
/*                                                                                                                                           */
/*  SPDX-License-Identifier: GPL-2.0-only OR LicenseRef-DocWire-Commercial                                                                   */
/*********************************************************************************************************************************************/

#ifndef DOCWIRE_OPENAI_ANALYZE_DATA_H
#define DOCWIRE_OPENAI_ANALYZE_DATA_H

#include "chat.h"

namespace docwire
{
namespace openai
{

class DllExport AnalyzeData : public Chat
{
public:
	AnalyzeData(const std::string& api_key, float temperature = 0);
	AnalyzeData(const AnalyzeData& other);
	virtual ~AnalyzeData();

	/**
	* @brief Creates clone of the AnalyzeData
	* @return new AnalyzeData
	*/
	AnalyzeData* clone() const override;
};

} // namespace openai
} // namespace docwire

#endif //DOCWIRE_OPENAI_ANALYZE_DATA_H
