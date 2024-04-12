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

#include "doc_parser.h"
#include <iostream>
#include "log.h"
#include "misc.h"

//Dirty hack, be we now what we are doing and this is internal library.
#define protected public
#define private public
#include "wv2/parser.h"
#include "wv2/parser9x.h"
#undef protected
#undef private

#include "exception.h"
#include "wv2/fields.h"
#include "wv2/handlers.h"
#include <mutex>
#include "oshared.h"
#include "wv2/paragraphproperties.h"
#include "wv2/parserfactory.h"
#include <stdio.h>
#include <sstream>
#include "wv2/ustring.h"
#include <vector>
#ifdef WIN32
	#include <windows.h>
#endif
#include <boost/signals2.hpp>
#include "wv2/word_helper.h"
#include "wv2/word97_generated.h"
#include "wv2/wvlog.h"
#include "xls_parser.h"
#include "thread_safe_ole_stream_reader.h"
#include "thread_safe_ole_storage.h"

namespace docwire
{

using namespace wvWare;

namespace
{
	std::mutex parser_factory_mutex_1;
	std::mutex parser_factory_mutex_2;
} // anonymous namespace

enum class TableState
{
	in_table,
	in_row,
	in_cell
};

struct CurrentHeaderFooter
{
	bool in_header;
	bool in_footer;
	CurrentHeaderFooter() : in_header(false), in_footer(false) {};
};

// constants are from MS Word Binary File Format Specification
enum FieldType
{
	FLT_NONE = 0,
	FLT_FILLIN = 0x27,
	FLT_EMBED = 0x3A,
	FLT_HYPERLINK = 0x58
};

enum FieldPart
{
	FIELD_PART_NONE,
	FIELD_PART_PARAMS,
	FIELD_PART_VALUE
};

struct CurrentState
{
	std::stack<TableState> table_state;
	CurrentHeaderFooter header_footer;
	std::list<std::string> obj_texts;
	std::list<std::string>::iterator obj_texts_iter;
	FieldType field_type;
	FieldPart field_part;
	UString field_params;
	UString field_value;
	CurrentState() : field_type(FLT_NONE), field_part(FIELD_PART_NONE) {};
};

struct Comment
{
	int fc;
	std::string text;
	std::string author;
};

static bool cp_to_stream_offset(const wvWare::Parser* parser, U32 cp, U32& stream_offset, bool* unicode_detected = NULL)
{
	const Parser9x* parser9 = dynamic_cast<const Parser9x*>(parser);
	if (parser9 == NULL)
	{
		docwire_log(warning) << "This is not a 9x parser.";
		return false;
	}
	U32 piece = 0;
	U32 offset = cp;
	if (parser9->m_plcfpcd == NULL)
	{
		docwire_log(warning) << "No pieces table found.";
		return false;
	}
	// Copied from wv2 code.
	PLCFIterator<Word97::PCD> it( *parser9->m_plcfpcd );
	for ( ; it.current(); ++it, ++piece ) {
		if ( it.currentLim() > cp && it.currentStart() <= cp )
		break;
		offset -= it.currentRun();
	}
	docwire_log(debug) << "Piece: " << piece << ", offset: " << offset;
	PLCFIterator<Word97::PCD> it2(parser9->m_plcfpcd->at( piece ) );
	if (!it2.current())
	{
		docwire_log(warning) << "Specified piece not found.";
		return false;
	}
	U32 fc = it2.current()->fc;   // Start FC of this piece
	docwire_log(debug) << "Piece start at FC " << fc << ".";
        bool unicode;
        parser9->realFC(fc, unicode);
	docwire_log(debug) << "After unicode transition piece start at FC " << fc << ".";
	if (offset != 0 )
            fc += unicode ? offset * 2 : offset;
	docwire_log(debug) << "Stream offset is " << fc << ".";
	stream_offset = fc;
	if (unicode_detected != NULL)
		*unicode_detected = unicode;
	return true;
}

static bool parse_comments(const wvWare::Parser* parser, std::vector<Comment>& comments)
{
	AbstractOLEStreamReader* reader = NULL;
	AbstractOLEStreamReader* table_reader = NULL;
	try
	{
		if (parser->fib().lcbPlcfandTxt == 0)
		{
			docwire_log(debug) << "No annotations.";
			return true;
		}

		U32 atn_part_cp = parser->fib().ccpText + parser->fib().ccpFtn + parser->fib().ccpHdd + parser->fib().ccpMcr;
		docwire_log(debug) << "Annotations part at CP " << atn_part_cp << ".";
		reader = parser->m_storage->createStreamReader("WordDocument");
		if (!reader)
		{
			docwire_log(error) << "Error opening WordDocument stream.";
			return false;
		}
		const Parser9x* parser9 = dynamic_cast<const Parser9x*>(parser);
		table_reader = parser->m_storage->createStreamReader(parser9->tableStream());
		if (!table_reader)
		{
			docwire_log(error) << "Error opening table stream.";
			delete reader;
			return false;
		}

		U32 annotation_txts_offset = parser->fib().fcPlcfandTxt;
		docwire_log(debug) << "Annotation texts table at offset " << annotation_txts_offset << ".";
		table_reader->seek(annotation_txts_offset);
		U32 annotation_begin_cp = table_reader->readU32();
		std::vector<std::string> annotations;
		for (;;)
		{
			U32 annotation_end_cp = table_reader->readU32();
			docwire_log(debug) << "Annotation text position (CP) from " << annotation_begin_cp << " to " << annotation_end_cp << ".";
			U32 stream_begin_offset;
			bool unicode;
			if (!cp_to_stream_offset(parser, atn_part_cp + annotation_begin_cp, stream_begin_offset, &unicode))
			{
				docwire_log(error) << "Converting annotation start position to stream offset failed.";
				delete reader;
				delete table_reader;
				return false;
			}
			U32 stream_end_offset;
			if (!cp_to_stream_offset(parser, atn_part_cp + annotation_end_cp, stream_end_offset))
			{
				docwire_log(error) << "Converting annotation end position to stream offset failed.";
				delete reader;
				delete table_reader;
				return false;
			}
			docwire_log(debug) << "Annotation text stream position from " << stream_begin_offset << " to " << stream_end_offset << ".";
			reader->seek(stream_begin_offset);
			U8 annotation_mark = reader->readU8();
			if (!annotation_mark == 0x05)
			{
				docwire_log(error) << "Incorrect annotation mark.";
				delete reader;
				delete table_reader;
				return false;
			}
			std::string annotation;
			while (reader->tell() < stream_end_offset - 1)
			{
				docwire_log(debug) << "Stream pos " << reader->tell();
				// warning TODO: Unicode support in comments
				if (unicode)
					reader->seek(1, SEEK_CUR); // skip unicode byte
				S8 ch = reader->readS8();
				if (ch >= 32 || (ch >= 8 && ch <= 13))
				{
					if (ch == '\r')
						annotation += "\n";
					else
						annotation += ch;
				}
			}
			docwire_log(debug) << "Annotation text: \"" << annotation << "\"";
			annotations.push_back(annotation);
			if (annotation_end_cp >= parser->fib().ccpAtn - 1)
				break;
			annotation_begin_cp = annotation_end_cp;
		}

		U32 annotation_owners_offset = parser->fib().fcGrpXstAtnOwners;
		U32 annotation_owners_len = parser->fib().lcbGrpXstAtnOwners;
		docwire_log(debug) << "Annotation owners table at offset " << annotation_owners_offset << " has length " << annotation_owners_len << ".";
		table_reader->seek(annotation_owners_offset);
		std::vector<std::string> owners;
		for (int total_len = 0; total_len < annotation_owners_len;)
		{
			U16 len = table_reader->readU16();
			total_len += 2;
			std::string owner;
			if (len * 2 + total_len > annotation_owners_len)
			{
				docwire_log(warning) << "Something is wrong with XST table. Authors of comments could not be parsed.";
				owners.clear();
				break;
			}
			for (int i = 0; i < len; i++)
			{
				S16 ch = table_reader->readS16();
				owner += (char)ch;
				total_len += 2;
			}
			docwire_log(debug) << "Owner \"" << owner << "\" found.";
			owners.push_back(owner);
		}

		U32 annotation_refs_offset = parser->fib().fcPlcfandRef;
		docwire_log(debug) << "Annotation refs table at offset " << annotation_refs_offset << ".";
		table_reader->seek(annotation_refs_offset);
		for (int i = 0;; i++)
		{
			U32 annotation_ref_cp = table_reader->readU32();
			if (annotation_ref_cp >= parser->fib().ccpText)
				break;
			docwire_log(debug) << "Annotation " << i << " references text at CP " << annotation_ref_cp << ".";
			U32 stream_offset;
			if (!cp_to_stream_offset(parser, annotation_ref_cp, stream_offset))
			{
				docwire_log(error) << "Converting annotation reference position to stream offset failed.";
				delete reader;
				delete table_reader;
				return false;
			}
			if (i < annotations.size())
			{
				docwire_log(debug) << "Annotation " << i << " references text at stream offset " << stream_offset << ".";
				Comment c;
				c.fc = stream_offset;
				c.text = annotations[i];
				comments.push_back(c);
			}
		}
		table_reader->seek(annotation_refs_offset + 4 * (comments.size() + 1));
		for (int i = 0; i < comments.size(); i++)
		{
			Word97::ATRD atrd(table_reader);
			if (atrd.ibst < owners.size())
			{
				docwire_log(debug) << "Annotation owner is \"" << owners[atrd.ibst] << "\", index " << atrd.ibst << ".";
				comments[i].author = owners[atrd.ibst];
			}
		}
		delete table_reader;
		delete reader;
		return true;
	}
	catch (std::bad_alloc& ba)
	{
		if (table_reader)
			delete table_reader;
		if (reader)
			delete reader;
		throw;
	}
}

class TextHandler : public wvWare::TextHandler
{
	private:
		const DOCParser* m_parent;
		const wvWare::Parser* m_parser;
		CurrentState* m_curr_state;
		bool m_comments_parsed;
		std::vector<Comment> m_comments;
		U32 m_prev_par_fc;

	public:
		TextHandler(const DOCParser* parent, const wvWare::Parser* parser, CurrentState* curr_state)
			: m_parent(parent), m_parser(parser), m_curr_state(curr_state), m_comments_parsed(false), m_prev_par_fc(0)
		{
			m_curr_state = curr_state;
		}

		void sectionStart(SharedPtr<const Word97::SEP> sep)
		{
		}

		void sectionEnd()
		{
		}

		void pageBreak()
		{
		}

		void paragraphStart(SharedPtr<const ParagraphProperties>
			paragraphProperties)
		{
			docwire_log_func();
			if (!m_curr_state->table_state.empty())
			{
				if (m_curr_state->table_state.top() == TableState::in_table)
				{
					m_parent->sendTag(tag::CloseTable{});
					m_curr_state->table_state.pop();
				}
				else if (m_curr_state->table_state.top() == TableState::in_row)
				{
					m_parent->sendTag(tag::TableCell{});
					m_curr_state->table_state.push(TableState::in_cell);
				}
			}
			m_parent->sendTag(tag::Paragraph{});
			if (((Parser9x*)m_parser)->m_currentParagraph->size() > 0)
			{
				if (m_comments_parsed)
				{
					for (int i = 0; i < m_comments.size(); i++)
					if (m_comments[i].fc >= m_prev_par_fc && m_comments[i].fc < ((Parser9x*)m_parser)->m_currentParagraph->back().m_startFC)
					{
						std::string comment_text = m_comments[i].text;
						std::replace(comment_text.begin(), comment_text.end(), '\x0b', '\n');
						m_parent->sendTag(tag::Comment{.author = m_comments[i].author, .comment = comment_text});
					}
				}
				else
				{
					if (!parse_comments(m_parser, m_comments))
					{
						docwire_log(error) << "Parsing comments failed.";
						m_comments.clear();
					}
					m_comments_parsed = true;
				}
			}
		}

		void paragraphEnd()
		{
			docwire_log_func();
			m_parent->sendTag(tag::CloseParagraph{});
			if (!((Parser9x*)m_parser)->m_currentParagraph->empty())
			{
				m_prev_par_fc = ((Parser9x*)m_parser)->m_currentParagraph->back().m_startFC;
			}
		}

		void runOfText (const UString &text, SharedPtr< const Word97::CHP > chp)
		{
			docwire_log_func();
			if (m_curr_state->field_part == FIELD_PART_PARAMS)
				m_curr_state->field_params += text;
			else if (m_curr_state->field_part == FIELD_PART_VALUE)
				m_curr_state->field_value += text;
			else
			{
				std::string t = ustring_to_string(text);
				std::replace(t.begin(), t.end(), '\x0b', '\n');
				m_parent->sendTag(tag::Text{.text = t});
			}
		}

		void specialCharacter(SpecialCharacter character,
			SharedPtr<const Word97::CHP> chp)
		{
		}

		void footnoteFound (FootnoteData::Type type, UChar character,
			SharedPtr<const Word97::CHP> chp,
			const FootnoteFunctor &parseFootnote)
		{
		}

		void footnoteAutoNumber(SharedPtr<const Word97::CHP> chp)
		{
		}

		void fieldStart(const FLD *fld,
			SharedPtr<const Word97::CHP> chp)
		{
			docwire_log_func();
			m_curr_state->field_type = (FieldType)fld->flt;
			m_curr_state->field_part = FIELD_PART_PARAMS;
			switch (fld->flt)
			{
				case FLT_EMBED:
					docwire_log(debug) << "Embedded OLE object reference found.";
					if (m_curr_state->obj_texts_iter == m_curr_state->obj_texts.end())
						docwire_log(warning) << "Unexpected OLE object reference.";
					else
					{
						std::string obj_text = *m_curr_state->obj_texts_iter;
						std::replace(obj_text.begin(), obj_text.end(), '\x0b', '\n');
						m_parent->sendTag(tag::Text{.text = obj_text});
						m_curr_state->obj_texts_iter++;
					}
					break;
				default:
					m_curr_state->field_params = "";
					m_curr_state->field_value = "";
			}
		}

		void fieldSeparator(const FLD* fld,
			SharedPtr<const Word97::CHP> chp)
		{
			docwire_log_func();
			m_curr_state->field_part = FIELD_PART_VALUE;
		}

		void fieldEnd(const FLD* fld,
			SharedPtr<const Word97::CHP> chp)
		{
			docwire_log_func();
			UString params = m_curr_state->field_params;
			int i = 0;
			while (i < params.length() && params[i] == ' ') i++;
			UString field_type;
			while (i < params.length() && params[i] != ' ')
			{
				field_type += UString(params[i]);
				i++;
			}
			while (i < params.length() && params[i] == ' ') i++;
			params = params.substr(i);
			UString res_text;
			switch (m_curr_state->field_type)
			{
				case FLT_FILLIN:
					res_text = params + UString(" ") + m_curr_state->field_value;
					break;
				case FLT_EMBED:
					break;
				case FLT_HYPERLINK:
					if (params[0] == '"')
					{
						UString hyperlink_url;
						for (i = 1; i < params.length() && params[i] != '"'; i++)
							hyperlink_url += UString(params[i]);
						m_parent->sendTag(tag::Link{.url = ustring_to_string(hyperlink_url)});
						m_parent->sendTag(tag::Text{.text = ustring_to_string(m_curr_state->field_value)});
						m_parent->sendTag(tag::CloseLink{});
					}
					else
						res_text = params + UString(" ") + m_curr_state->field_value;
					break;
				default:
					res_text = m_curr_state->field_value;
			}
			m_curr_state->field_type = FLT_NONE;
			m_curr_state->field_part = FIELD_PART_NONE;
			std::string t = ustring_to_string(res_text);
			std::replace(t.begin(), t.end(), '\x0b', '\n');
			m_parent->sendTag(tag::Text{.text = t});
		}

		void endOfDocument()
		{
			docwire_log_func();
			if (m_comments_parsed)
				for (int i = 0; i < m_comments.size(); i++)
					if (m_comments[i].fc >= m_prev_par_fc)
					{
						std::string comment_text = m_comments[i].text;
						std::replace(comment_text.begin(), comment_text.end(), '\x0b', '\n');
						m_parent->sendTag(tag::Comment{.author = m_comments[i].author, .comment = comment_text});
					}
		}
};

class TableHandler : public wvWare::TableHandler
{
	private:
		const DOCParser* m_parent;
		CurrentState& m_current_state;

	public:
		TableHandler(const DOCParser* parent, CurrentState& current_state)
			: m_parent(parent), m_current_state(current_state)
		{
		}

		void tableRowStart(SharedPtr<const Word97::TAP> tap)
		{
			docwire_log_func();
			if (m_current_state.table_state.empty() || m_current_state.table_state.top() == TableState::in_cell)
			{
				m_parent->sendTag(tag::Table{});
				m_current_state.table_state.push(TableState::in_table);
			}
			if (m_current_state.table_state.top() != TableState::in_table)
				throw DOCParser::ParsingError("Unexpected start of table row");
			m_parent->sendTag(tag::TableRow{});
			m_current_state.table_state.push(TableState::in_row);
		}

		void tableRowEnd()
		{
			docwire_log_func();
			if (m_current_state.table_state.empty())
				throw DOCParser::ParsingError("Unexpected end of table row");
			if (m_current_state.table_state.top() == TableState::in_cell)
			{
				m_parent->sendTag(tag::CloseTableCell{});
				m_current_state.table_state.pop();
			}
			if (m_current_state.table_state.empty() || m_current_state.table_state.top() != TableState::in_row)
				throw DOCParser::ParsingError("Unexpected end of table row");
			m_parent->sendTag(tag::CloseTableRow{});
			m_current_state.table_state.pop();
		}

		void tableCellStart()
		{
			docwire_log_func();
			if (m_current_state.table_state.empty() || m_current_state.table_state.top() != TableState::in_row)
				throw DOCParser::ParsingError("Unexpected start of table cell");
			m_parent->sendTag(tag::TableCell{});
			m_current_state.table_state.push(TableState::in_cell);
		}

		void tableCellEnd()
		{
			docwire_log_func();
			if (!m_current_state.table_state.empty() && m_current_state.table_state.top() == TableState::in_table)
			{
				m_parent->sendTag(tag::CloseTable{});
				m_current_state.table_state.pop();
			}
			if (m_current_state.table_state.empty() || m_current_state.table_state.top() != TableState::in_cell)
				throw DOCParser::ParsingError("Unexpected end of table cell");
			m_parent->sendTag(tag::CloseTableCell{});
			m_current_state.table_state.pop();
		}
};

class SubDocumentHandler : public wvWare::SubDocumentHandler
{
	private:
		const DOCParser* m_parent;
		CurrentHeaderFooter* m_curr_header_footer;
	
	public:
		SubDocumentHandler(const DOCParser* parent, CurrentHeaderFooter* curr_header_footer)
			: m_parent(parent), m_curr_header_footer(curr_header_footer)
		{
		}

		virtual void headerStart(HeaderData::Type type)
		{
			docwire_log_func();
			switch (type)
			{
				case HeaderData::HeaderOdd:
				case HeaderData::HeaderEven:
				case HeaderData::HeaderFirst:
					m_curr_header_footer->in_header = true;
					m_parent->sendTag(tag::Header{});
					break;
				case HeaderData::FooterOdd:
				case HeaderData::FooterEven:
				case HeaderData::FooterFirst:
					m_curr_header_footer->in_footer = true;
					m_parent->sendTag(tag::Footer{});
					break;
			}
		}

		virtual void headerEnd()
		{
			docwire_log_func();
			if (m_curr_header_footer->in_header)
				m_parent->sendTag(tag::CloseHeader{});
			if (m_curr_header_footer->in_footer)
				m_parent->sendTag(tag::CloseFooter{});
			m_curr_header_footer->in_header = false;
			m_curr_header_footer->in_footer = false;
		}
};

struct DOCParser::Implementation
{
	const char* m_buffer;
	size_t m_buffer_size;
	std::string m_file_name;
};

DOCParser::DOCParser(const std::string& file_name)
{
	impl = NULL;
	try
	{
		impl = new Implementation();
		impl->m_file_name = file_name;
		impl->m_buffer = NULL;
		impl->m_buffer_size = 0;
	}
	catch (std::bad_alloc& ba)
	{
		if (impl)
			delete impl;
		throw;
	}
}

DOCParser::DOCParser(const char *buffer, size_t size)
{
	impl = NULL;
	try
	{
		impl = new Implementation();
		impl->m_file_name = "Memory buffer";
		impl->m_buffer = buffer;
		impl->m_buffer_size = size;
	}
	catch (std::bad_alloc& ba)
	{
		if (impl)
			delete impl;
		throw;
	}
}

DOCParser::~DOCParser()
{
	delete impl;
}

bool DOCParser::isDOC()
{
	FILE* f = NULL;
	if (!impl->m_buffer)
		f = fopen(impl->m_file_name.c_str(), "r");
	if (f == NULL && !impl->m_buffer)
		throw RuntimeError("Error opening file " + impl->m_file_name);
	if (f)
		fclose(f);
	cerr_log_redirection cerr_redirection(docwire_current_source_location());
	ThreadSafeOLEStorage* storage = NULL;
	//storage will be deleted inside parser from wv2 library
	if (impl->m_buffer)
		storage = new ThreadSafeOLEStorage(impl->m_buffer, impl->m_buffer_size);
	else
		storage = new ThreadSafeOLEStorage(impl->m_file_name);
	SharedPtr<wvWare::Parser> parser;
	{
		std::lock_guard<std::mutex> parser_factory_mutex_1_lock(parser_factory_mutex_1);
		parser = ParserFactory::createParser(storage);
	}
	cerr_redirection.restore();
	if (!parser || !parser->isOk())
	{
		docwire_log(error) << "Creating parser failed.";
		return false;
	}
	return true;
}

void DOCParser::parse() const
{
	docwire_log(debug) << "Using DOC parser.";
	sendTag(metaData());

	CurrentState curr_state;
	docwire_log(debug) << "Opening " << impl->m_file_name << " as OLE file to parse all embedded objects in supported formats.";
	//Pointer to storage will be passed to parser from wv2 library. This pointer will be deleted, so allocate storage on heap
	ThreadSafeOLEStorage* storage = NULL;
	try
	{
		if (impl->m_buffer)
			storage = new ThreadSafeOLEStorage(impl->m_buffer, impl->m_buffer_size);
		else
			storage = new ThreadSafeOLEStorage(impl->m_file_name);
		if (!storage->isValid())
			throw RuntimeError("Error opening " + impl->m_file_name + " as OLE file");
		if (storage->enterDirectory("ObjectPool"))
		{
			docwire_log(debug) << "ObjectPool found, embedded OLE objects probably exist.";
			std::vector<std::string> obj_list;
			if (!storage->getStreamsAndStoragesList(obj_list))
				throw RuntimeError("Error while loading list of streams and storages in ObjectPool directory. OLE Storage has reported an error: " + storage->getLastError());
			for (size_t i = 0; i < obj_list.size(); ++i)
			{
				docwire_log(debug) << "OLE object entry found: " << obj_list[i];
				std::string obj_text;
				std::string currect_dir = obj_list[i];
				if (storage->enterDirectory(obj_list[i]))
				{
					std::vector<std::string> obj_list;
					if (!storage->getStreamsAndStoragesList(obj_list))
						throw RuntimeError("Error while loading list of streams and storages in " + currect_dir + " directory. OLE Storage has reported an error: " + storage->getLastError());
					if (find(obj_list.begin(), obj_list.end(), "Workbook") != obj_list.end())
					{
						docwire_log(debug) << "Embedded MS Excel workbook detected.";
						docwire_log(debug) << "Using XLS parser.";
						try
						{
							XLSParser xls("");
							obj_text = xls.plainText(*storage);
						}
						catch (const std::exception& e)
						{
							docwire_log(error) << "Error while parsing embedded MS Excel workbook:\n" << e.what();
						}
					}
					storage->leaveDirectory();
				}
				curr_state.obj_texts.push_back(obj_text);
			}
		}
		else
		{
			docwire_log(debug) << "No ObjectPool found, embedded OLE objects probably do not exist.";
		}
		storage->leaveDirectory();
		curr_state.obj_texts_iter = curr_state.obj_texts.begin();
	}
	catch (const std::exception& e)
	{
		if (storage)
			delete storage;
		throw;
	}
	cerr_log_redirection cerr_redirection(docwire_current_source_location());
	SharedPtr<wvWare::Parser> parser;
	{
		std::lock_guard<std::mutex> parser_factory_mutex_2_lock(parser_factory_mutex_2);
		parser = ParserFactory::createParser(storage);
	}
	cerr_redirection.restore();
	if (!parser || !parser->isOk())
	{
		if (parser && parser->fib().fEncrypted)
			throw EncryptedFileException("File is encrypted");
		throw RuntimeError("Creating parser failed");
	}
	TextHandler text_handler(this, parser, &curr_state);
	parser->setTextHandler(&text_handler);
	TableHandler table_handler(this, curr_state);
	parser->setTableHandler(&table_handler);
	SubDocumentHandler sub_document_handler(this, &curr_state.header_footer);
	parser->setSubDocumentHandler(&sub_document_handler);
	cerr_redirection.redirect();
	bool res = parser->parse();
	cerr_redirection.restore();
	if (!res)
		throw RuntimeError("Parsing document failed");
	text_handler.endOfDocument();
}

tag::Metadata DOCParser::metaData() const
{
	tag::Metadata meta;
	ThreadSafeOLEStorage* storage = NULL;
	try
	{
		if (impl->m_buffer)
			storage = new ThreadSafeOLEStorage(impl->m_buffer, impl->m_buffer_size);
		else
			storage = new ThreadSafeOLEStorage(impl->m_file_name);
		parse_oshared_summary_info(*storage, meta);
		delete storage;
		storage = NULL;
		return meta;
	}
	catch (const std::exception& e)
	{
		if (storage)
			delete storage;
		throw;
	}
}

Parser& DOCParser::withParameters(const ParserParameters &parameters)
{
	Parser::withParameters(parameters);
	return *this;
}

} // namespace docwire
