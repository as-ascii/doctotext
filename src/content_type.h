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

#ifndef DOCWIRE_CONTENT_TYPE_H
#define DOCWIRE_CONTENT_TYPE_H

#include "chain_element.h"
#include "content_type_by_signature.h"
#include "ref_or_owned.h"

namespace docwire::content_type
{

DllExport void detect(data_source& data, const by_signature::database& signatures_db_to_use = by_signature::database{});

class detector : public ChainElement
{
public:

    detector(ref_or_owned<by_signature::database> signatures_db_to_use = by_signature::database{})
        : m_signatures_db_to_use(signatures_db_to_use) {}

    void process(Info& info) override
    {
        if (!std::holds_alternative<data_source>(info.tag))
        {
	        emit(info);
		    return;
	    }
	    data_source& data = std::get<data_source>(info.tag);
        content_type::detect(data, m_signatures_db_to_use.get());
        emit(info);
    }

    bool is_leaf() const override
	{
		return false;
	}

private:
    ref_or_owned<by_signature::database> m_signatures_db_to_use;
};

} // namespace docwire::content_type

#endif // DOCWIRE_CONTENT_TYPE
