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

#ifndef DOCWIRE_OPENAI_TEXT_TO_SPEECH_H
#define DOCWIRE_OPENAI_TEXT_TO_SPEECH_H

#include "chain_element.h"
#include "exception.h"

namespace docwire
{
namespace openai
{

class DllExport TextToSpeech : public ChainElement
{
public:
	enum class Model
	{
		tts1, tts1_hd
	};

	enum class Voice
	{
		alloy, echo, fable, onyx, nova, shimmer
	};

	TextToSpeech(const std::string& api_key, Model model = Model::tts1, Voice voice = Voice::alloy);
	TextToSpeech(const TextToSpeech& other);
	virtual ~TextToSpeech();

	/**
	* @brief Executes transform operation for given node data.
	* @see docwire::Info
	* @param info
	*/
	void process(Info &info) const;

	bool is_leaf() const override
	{
		return false;
	}

	DOCWIRE_EXCEPTION_DEFINE(HttpError, RuntimeError);
	DOCWIRE_EXCEPTION_DEFINE(ParseResponseError, RuntimeError);

private:
	struct Implementation;
	std::unique_ptr<Implementation> impl;
};

} // namespace openai
} // namespace docwire

#endif //DOCWIRE_OPENAI_TEXT_TO_SPEECH_H
