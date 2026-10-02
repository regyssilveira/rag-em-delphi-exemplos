unit Rag.Types;

interface

type
  TDocument = record
    Id: string;
    Source: string;
    Text: string;
    Access: string;
  end;

  TChunk = record
    Id: string;
    DocumentId: string;
    Source: string;
    Text: string;
    Access: string;
    StartOffset: Integer;
  end;

  TSearchResult = record
    Chunk: TChunk;
    Score: Double;
  end;

implementation

end.
