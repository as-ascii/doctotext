/***************************************************************************************************************************************************/
/*  DocWire SDK - A multifaceted, data extraction software development toolkit that converts all sorts of files to plain text and html.            */
/*  Written in C++, this data extraction tool has a parser able to convert PST & OST files along with a brand new API for better file processing.  */
/*  To enhance its utility, DocWire, as a data extraction tool, can be integrated with other data mining and data analytics applications.          */
/*  It comes equipped with a high grade, scriptable and trainable OCR that has LSTM neural networks based character recognition.                   */
/*                                                                                                                                                 */
/*  This document parser is able to extract metadata along with annotations and supports a list of formats that include:                           */
/*  DOC, XLS, XLSB, PPT, RTF, ODF (ODT, ODS, ODP), OOXML (DOCX, XLSX, PPTX), iWork (PAGES, NUMBERS, KEYNOTE), ODFXML (FODP, FODS, FODT),           */
/*  PDF, EML, HTML, Outlook (PST, OST), Image (JPG, JPEG, JFIF, BMP, PNM, PNG, TIFF, WEBP), Archives (ZIP, TAR, RAR, GZ, BZ2, XZ)                  */
/*  and DICOM (DCM)                                                                                                                                */
/*                                                                                                                                                 */
/*  Copyright (c) SILVERCODERS Ltd                                                                                                                 */
/*  http://silvercoders.com                                                                                                                        */
/*                                                                                                                                                 */
/*  Project homepage:                                                                                                                              */
/*  https://github.com/docwire/docwire                                                                                                             */
/*  https://www.docwire.io/                                                                                                                        */
/*                                                                                                                                                 */
/*  The GNU General Public License version 2 as published by the Free Software Foundation and found in the file COPYING.GPL permits                */
/*  the distribution and/or modification of this application.                                                                                      */
/*                                                                                                                                                 */
/*  Please keep in mind that any attempt to circumvent the terms of the GNU General Public License by employing wrappers, pipelines,               */
/*  client/server protocols, etc. is illegal. You must purchase a commercial license if your program, which is distributed under a license         */
/*  other than the GNU General Public License version 2, directly or indirectly calls any portion of this code.                                    */
/*  Simply stop using the product if you disagree with this viewpoint.                                                                             */
/*                                                                                                                                                 */
/*  According to the terms of the license provided by SILVERCODERS and included in the file COPYING.COM, licensees in possession of                */
/*  a current commercial license for this product may use this file.                                                                               */
/*                                                                                                                                                 */
/*  This program is provided WITHOUT ANY WARRANTY, not even the implicit warranty of merchantability or fitness for a particular purpose.          */
/*  It is supplied in the hope that it will be useful.                                                                                             */
/***************************************************************************************************************************************************/

#include "html_exporter.h"

#include "html_writer.h"
#include "parser.h"
#include <sstream>

namespace docwire
{

struct HtmlExporter::Implementation
{
	RestoreOriginalAttributes m_restore_original_attributes;
	std::stringstream m_stream;
	HtmlWriter m_writer;
	Implementation(RestoreOriginalAttributes restore_original_attributes)
		: m_restore_original_attributes(restore_original_attributes),
		m_writer(static_cast<HtmlWriter::RestoreOriginalAttributes>(m_restore_original_attributes))
	{}
};

HtmlExporter::HtmlExporter(RestoreOriginalAttributes restore_original_attributes)
  : impl(new Implementation(restore_original_attributes), ImplementationDeleter())
{}

HtmlExporter::HtmlExporter(const HtmlExporter& other)
	: impl(new Implementation(other.impl->m_restore_original_attributes), ImplementationDeleter())
{
}

void HtmlExporter::process(Info &info) const
{
	if (info.tag_name == StandardTag::TAG_DOCUMENT)
		impl->m_stream.clear();
	impl->m_writer.write_to(info, impl->m_stream);
	if (info.tag_name == StandardTag::TAG_CLOSE_DOCUMENT)
	{
		Info info(StandardTag::TAG_FILE, "", {{"stream", (std::istream*)&impl->m_stream}, {"name", ""}});
		emit(info);
	}
}

void HtmlExporter::ImplementationDeleter::operator()(HtmlExporter::Implementation* impl)
{
	delete impl;
}

} // namespace docwire
