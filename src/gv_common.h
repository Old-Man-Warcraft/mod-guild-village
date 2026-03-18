#pragma once

#include "Config.h"
#include "DataMap.h"
#include "DatabaseEnv.h"
#include "StringFormat.h"

#include <algorithm>
#include <cctype>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_set>
#include <utility>

namespace GuildVillage
{
    struct GVPhaseData : public DataMap::Base
    {
        uint32 phaseMask = 0;
    };

    inline bool IsSingleBitPhaseMask(uint32 phaseMask)
    {
        return phaseMask && !(phaseMask & (phaseMask - 1));
    }

    inline bool IsUsableVillagePhaseMask(uint32 phaseMask)
    {
        return IsSingleBitPhaseMask(phaseMask) && phaseMask != 1;
    }

    inline uint32 GuildVillagePhaseCapacity()
    {
        return 31;
    }

    inline std::optional<uint32> FindFreeVillagePhaseMask(std::unordered_set<uint32> const& usedMasks)
    {
        for (uint32 bit = 1; bit < 32; ++bit)
        {
            uint32 phaseMask = uint32(1) << bit;
            if (usedMasks.find(phaseMask) == usedMasks.end())
                return phaseMask;
        }

        return std::nullopt;
    }

    inline std::string DatabaseName()
    {
        std::string databaseName =
            sConfigMgr->GetOption<std::string>("GuildVillage.Database.Name", "customs");

        databaseName.erase(
            std::remove_if(databaseName.begin(), databaseName.end(),
                [](unsigned char ch) { return std::isspace(ch); }),
            databaseName.end());

        if (databaseName.empty())
            return "customs";

        return databaseName;
    }

    inline bool AutoCreateDatabase()
    {
        return sConfigMgr->GetOption<bool>("GuildVillage.Database.AutoCreate", false);
    }

    inline std::string QuoteIdentifier(std::string const& identifier)
    {
        std::string quoted;
        quoted.reserve(identifier.size() + 2);
        quoted.push_back('`');

        for (char ch : identifier)
        {
            if (ch == '`')
                quoted.push_back('`');

            quoted.push_back(ch);
        }

        quoted.push_back('`');
        return quoted;
    }

    inline std::string QuotedDatabaseName()
    {
        return QuoteIdentifier(DatabaseName());
    }

    inline void ReplaceAll(std::string& sql, std::string_view from, std::string const& to)
    {
        if (from.empty())
            return;

        size_t pos = 0;
        while ((pos = sql.find(from, pos)) != std::string::npos)
        {
            sql.replace(pos, from.size(), to);
            pos += to.size();
        }
    }

    inline std::string RewriteWorldSql(std::string sql)
    {
        std::string const qualifiedDatabase = QuotedDatabaseName() + ".";

        ReplaceAll(sql, "`customs`.", qualifiedDatabase);
        ReplaceAll(sql, "customs.", qualifiedDatabase);

        return sql;
    }

    class WorldDatabaseProxy
    {
    public:
        template <typename... Args>
        QueryResult Query(std::string sql, Args&&... args) const
        {
            return ::WorldDatabase.Query(
                RewriteWorldSql(std::move(sql)), std::forward<Args>(args)...);
        }

        template <typename... Args>
        void Execute(std::string sql, Args&&... args) const
        {
            ::WorldDatabase.Execute(
                RewriteWorldSql(std::move(sql)), std::forward<Args>(args)...);
        }

        template <typename... Args>
        void DirectExecute(std::string sql, Args&&... args) const
        {
            ::WorldDatabase.DirectExecute(
                RewriteWorldSql(std::move(sql)), std::forward<Args>(args)...);
        }

        WorldDatabaseTransaction BeginTransaction() const
        {
            return ::WorldDatabase.BeginTransaction();
        }

        void CommitTransaction(WorldDatabaseTransaction transaction) const
        {
            ::WorldDatabase.CommitTransaction(std::move(transaction));
        }
    };

    inline WorldDatabaseProxy GVWorldDatabase;
}

#define WorldDatabase ::GuildVillage::GVWorldDatabase
