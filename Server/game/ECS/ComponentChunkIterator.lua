local ComponentChunkIterator = BaseClass()
ECS.ComponentChunkIterator = ComponentChunkIterator

function ComponentChunkIterator:Constructor( match, globalSystemVersion, filter )
	self.m_FirstMatchingArchetype = match
	self.m_CurrentMatchingArchetype = match
	self.IndexInComponentGroup = -1
	self.m_CurrentChunk = nil
	self.m_CurrentArchetypeEntityIndex = math.huge
	self.m_CurrentArchetypeIndex = math.huge
	self.m_CurrentChunkEntityIndex = 0
	self.m_CurrentChunkIndex = 0
	self.m_GlobalSystemVersion = globalSystemVersion
	self.m_Filter = filter
end

function ComponentChunkIterator:MoveToEntityIndex( index )
    if not self.m_Filter.RequiresMatchesFilter then
        if index < self.m_CurrentArchetypeEntityIndex then
            self.m_CurrentMatchingArchetype = self.m_FirstMatchingArchetype
            self.m_CurrentArchetypeEntityIndex = 0
            self.m_CurrentChunk = self.m_CurrentMatchingArchetype.Archetype.ChunkList.Begin
            self.m_CurrentChunkEntityIndex = 0
        end

        while index >= self.m_CurrentArchetypeEntityIndex + self.m_CurrentMatchingArchetype.Archetype.EntityCount do
            self.m_CurrentArchetypeEntityIndex = self.m_CurrentArchetypeEntityIndex+self.m_CurrentMatchingArchetype.Archetype.EntityCount
            self.m_CurrentMatchingArchetype = self.m_CurrentMatchingArchetype.Next
            self.m_CurrentChunk = self.m_CurrentMatchingArchetype.Archetype.ChunkList.Begin
            self.m_CurrentChunkEntityIndex = 0
        end

        index = index - self.m_CurrentArchetypeEntityIndex
        if index < self.m_CurrentChunkEntityIndex then
            self.m_CurrentChunk = self.m_CurrentMatchingArchetype.Archetype.ChunkList.Begin
            self.m_CurrentChunkEntityIndex = 0
        end

        while index >= self.m_CurrentChunkEntityIndex + self.m_CurrentChunk.Count do
            self.m_CurrentChunkEntityIndex = self.m_CurrentChunkEntityIndex + self.m_CurrentChunk.Count
            self.m_CurrentChunk = self.m_CurrentChunk.ChunkListNode.Next
        end
    end
end

function ComponentChunkIterator:UpdateCacheToCurrentChunk( cache, isWriting, indexInComponentGroup )
    local archetype = self.m_CurrentMatchingArchetype.Archetype

    local indexInArchetype = self.m_CurrentMatchingArchetype.IndexInArchetype[indexInComponentGroup]

    cache.CachedBeginIndex = self.m_CurrentChunkEntityIndex + self.m_CurrentArchetypeEntityIndex
    cache.CachedEndIndex = cache.CachedBeginIndex + self.m_CurrentChunk.Count
    cache.CachedSizeOf = archetype.SizeOfs[indexInArchetype]
    cache.CachedPtr = self.m_CurrentChunk.Buffer + archetype.Offsets[indexInArchetype] -
                      cache.CachedBeginIndex * cache.CachedSizeOf
    cache.IsWriting = isWriting
    if isWriting then
        self.m_CurrentChunk.ChangeVersion[indexInArchetype] = self.m_GlobalSystemVersion
    end
end        

function ComponentChunkIterator:MoveToEntityIndexAndUpdateCache( index, cache, isWriting )
	self:MoveToEntityIndex(index)
    self:UpdateCacheToCurrentChunk(cache, isWriting, IndexInComponentGroup)
end

function ComponentChunkIterator.CalculateLength( firstMatchingArchetype, filter )
    local length = 0
    if not filter.RequiresMatchesFilter then
        local match = firstMatchingArchetype
        while match~=nil do
            length = length + match.Archetype.EntityCount
            match = match.Next
        end
    else
        local match = firstMatchingArchetype
        while match~=nil do
            length = length + match.Archetype.EntityCount
            if match.Archetype.EntityCount > 0 then
                local archeType = match.Archetype
                local c = archeType.ChunkList.Begin
                while c ~= archeType.ChunkList.End do
                    if c:MatchesFilter(match, filter) then
                        length = length + c.Count
                    end
                    c = c.ChunkListNode.Next
                end
            end
            match = match.Next
        end
    end

    return length;
end