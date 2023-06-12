/***************************************************************************************************************************************************/
/*  DocToText - A multifaceted, data extraction software development toolkit that converts all sorts of files to plain text and html.              */
/*  Written in C++, this data extraction tool has a parser able to convert PST & OST files along with a brand new API for better file processing.  */
/*  To enhance its utility, DocToText, as a data extraction tool, can be integrated with other data mining and data analytics applications.        */
/*  It comes equipped with a high grade, scriptable and trainable OCR that has LSTM neural networks based character recognition.                   */
/*                                                                                                                                                 */
/*  This document parser is able to extract metadata along with annotations and supports a list of formats that include:                           */
/*  DOC, XLS, XLSB, PPT, RTF, ODF (ODT, ODS, ODP), OOXML (DOCX, XLSX, PPTX), iWork (PAGES, NUMBERS, KEYNOTE), ODFXML (FODP, FODS, FODT),           */
/*  PDF, EML, HTML, Outlook (PST, OST), Image (JPG, JPEG, JFIF, BMP, PNM, PNG, TIFF, WEBP) and DICOM (DCM)                                         */
/*                                                                                                                                                 */
/*  Copyright (c) SILVERCODERS Ltd                                                                                                                 */
/*  http://silvercoders.com                                                                                                                        */
/*                                                                                                                                                 */
/*  Project homepage:                                                                                                                              */
/*  http://silvercoders.com/en/products/doctotext                                                                                                  */
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

#include <memory>
#include "html_writer.h"
#include "parser.h"
namespace doctotext
{
using doctotext::StandardTag;

std::map<std::string, std::function<std::shared_ptr<TextElement>(const doctotext::Info &info)>> writers = {
  {StandardTag::TAG_P, [](const doctotext::Info &info) { return std::make_shared<TextElement>("<p>"); }},
  {StandardTag::TAG_CLOSE_P, [](const doctotext::Info &info) { return std::make_shared<TextElement>("</p>"); }},
  {StandardTag::TAG_B, [](const doctotext::Info &info) { return std::make_shared<TextElement>("<b>"); }},
  {StandardTag::TAG_CLOSE_B, [](const doctotext::Info &info) { return std::make_shared<TextElement>("</b>"); }},
  {StandardTag::TAG_I, [](const doctotext::Info &info) { return std::make_shared<TextElement>("<i>"); }},
  {StandardTag::TAG_CLOSE_I, [](const doctotext::Info &info) { return std::make_shared<TextElement>("</i>"); }},
  {StandardTag::TAG_U, [](const doctotext::Info &info) { return std::make_shared<TextElement>("<u>"); }},
  {StandardTag::TAG_CLOSE_U, [](const doctotext::Info &info) { return std::make_shared<TextElement>("</u>"); }},
  {StandardTag::TAG_TABLE, [](const doctotext::Info &info) { return std::make_shared<TextElement>("<table>"); }},
  {StandardTag::TAG_CLOSE_TABLE, [](const doctotext::Info &info) { return std::make_shared<TextElement>("</table>"); }},
  {StandardTag::TAG_TR, [](const doctotext::Info &info) { return std::make_shared<TextElement>("<tr>"); }},
  {StandardTag::TAG_CLOSE_TR, [](const doctotext::Info &info) { return std::make_shared<TextElement>("</tr>"); }},
  {StandardTag::TAG_TD, [](const doctotext::Info &info) { return std::make_shared<TextElement>("<td>"); }},
  {StandardTag::TAG_CLOSE_TD, [](const doctotext::Info &info) { return std::make_shared<TextElement>("</td>"); }},
  {StandardTag::TAG_BR, [](const doctotext::Info &info) { return std::make_shared<TextElement>("<br />"); }},
  {StandardTag::TAG_TEXT, [](const doctotext::Info &info) { return std::make_shared<TextElement>(info.plain_text); }}};

void
HtmlWriter::write_header(std::ostream &stream) const
{
  stream << "<!DOCTYPE html>\n"
         << "<html>\n"
         << "<head>\n"
         << "<meta charset=\"utf-8\">\n"
         << "<title>DocToText</title>\n"
         << "</head>\n"
         << "<body>\n";
}

void
HtmlWriter::write_footer(std::ostream &stream) const
{
  stream << "</body>\n"
         << "</html>\n";
}

void
HtmlWriter::write_to(const doctotext::Info &info, std::ostream &stream)
{
  auto writer_iterator = writers.find(info.tag_name);
  if (writer_iterator != writers.end())
  {
    writer_iterator->second(info)->write_to(stream);
  }
}

Writer*
HtmlWriter::clone() const
{
return new HtmlWriter(*this);
}
} // namespace doctotext








