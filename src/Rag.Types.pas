unit Rag.Types;

interface

type
  TDocument = record
    Id: string;
    Source: string;
    Text: string;
    Access: string;
    PageNumber: Integer;
  end;

  TChunk = record
    Id: string;
    DocumentId: string;
    Source: string;
    Text: string;
    Access: string;
    PageNumber: Integer;
    StartOffset: Integer;
  end;

  TSearchResult = record
    Chunk: TChunk;
    Score: Double;
  end;

implementation

end.
