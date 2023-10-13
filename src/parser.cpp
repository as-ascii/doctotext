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

#include <boost/signals2.hpp>

#include "parser.h"

#include "log.h"

namespace docwire
{

struct Parser::Implementation
{
  Info
  sendTag(const std::string& tag_name, const std::string& text, const std::map<std::string, std::any> &attributes) const
  {
    Info info(tag_name, text, attributes);
    m_on_new_node_signal(info);
    return info;
  }

  void
  onNewNode(NewNodeCallback callback)
  {
    m_on_new_node_signal.connect(callback);
  }

private:
  boost::signals2::signal<void(Info &info)> m_on_new_node_signal;
};

void Parser::ImplementationDeleter::operator()(Parser::Implementation *impl)
{
  delete impl;
}

Parser::Parser(const std::shared_ptr<ParserManager> &inParserManager)
    : m_parser_manager(inParserManager)
{
  base_impl = std::unique_ptr<Implementation, ImplementationDeleter>{new Implementation{}, ImplementationDeleter{}};
}

Info Parser::sendTag(const std::string& tag_name, const std::string& text, const std::map<std::string, std::any> &attributes) const
{
  docwire_log(debug) << "Sending tag \"" << tag_name << "\" with text [" << text << "]";
  return base_impl->sendTag(tag_name, text, attributes);
}

Info Parser::sendTag(const Info &info) const
{
  return base_impl->sendTag(info.tag_name, info.plain_text, info.attributes);
}

Parser& Parser::addOnNewNodeCallback(NewNodeCallback callback)
{
  base_impl->onNewNode(callback);
  return *this;
}

Parser& Parser::withParameters(const ParserParameters &parameters)
{
    m_parameters += parameters;
    return *this;
}

FormattingStyle Parser::getFormattingStyle() const
{
  auto formatting_style = m_parameters.getParameterValue<FormattingStyle>("formatting_style");
  if (formatting_style)
  {
    return *formatting_style;
  }
  return FormattingStyle();
}

} // namespace docwire
