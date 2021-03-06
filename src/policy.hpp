/*
  Copyright (c) 2016, Antonio SJ Musumeci <trapexit@spawn.link>

  Permission to use, copy, modify, and/or distribute this software for any
  purpose with or without fee is hereby granted, provided that the above
  copyright notice and this permission notice appear in all copies.

  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*/

#pragma once

#include <string>
#include <vector>
#include <map>

#include "fs.hpp"
#include "category.hpp"

#define POLICY_SUCCESS 0
#define POLICY_FAIL -1
#define POLICY_SUCCEEDED(RV) ((RV) == POLICY_SUCCESS)
#define POLICY_FAILED(RV) ((RV) == POLICY_FAIL)
#define POLICY_FAIL_ERRNO(ERRNO) (errno=ERRNO,POLICY_FAIL)
#define POLICY_FAIL_ENOENT POLICY_FAIL_ERRNO(ENOENT)

namespace mergerfs
{
  class Policy
  {
  public:
    struct Enum
    {
      enum Type
        {
          invalid = -1,
          BEGIN   = 0,
          all     = BEGIN,
          epall,
          epff,
          eplfs,
          eplus,
          epmfs,
          eprand,
          erofs,
          ff,
          lfs,
          lus,
          mfs,
          newest,
          rand,
          END
        };

      static size_t begin() { return BEGIN; }
      static size_t end()   { return END; }
    };

    struct Func
    {
      typedef std::string string;
      typedef std::vector<string> strvec;
      typedef std::vector<const string*> cstrptrvec;
      typedef const string cstring;
      typedef const uint64_t cuint64_t;
      typedef const strvec cstrvec;
      typedef const Category::Enum::Type CType;

      typedef int (*Ptr)(CType,cstrvec &,const char *,cuint64_t,cstrptrvec &);

      template <CType T>
      class Base
      {
      public:
        Base(const Policy *p)
          : func(p->_func)
        {}

        int
        operator()(cstrvec &b,const char *c,cuint64_t d,cstrptrvec &e)
        {
          return func(T,b,c,d,e);
        }

      private:
        const Ptr func;
      };

      typedef Base<Category::Enum::action> Action;
      typedef Base<Category::Enum::create> Create;
      typedef Base<Category::Enum::search> Search;

      static int invalid(CType,cstrvec&,const char *,cuint64_t,cstrptrvec&);
      static int all(CType,cstrvec&,const char*,cuint64_t,cstrptrvec&);
      static int epall(CType,cstrvec&,const char*,cuint64_t,cstrptrvec&);
      static int epff(CType,cstrvec&,const char *,cuint64_t,cstrptrvec&);
      static int eplfs(CType,cstrvec&,const char *,cuint64_t,cstrptrvec&);
      static int eplus(CType,cstrvec&,const char *,cuint64_t,cstrptrvec&);
      static int epmfs(CType,cstrvec&,const char *,cuint64_t,cstrptrvec&);
      static int eprand(CType,cstrvec&,const char *,cuint64_t,cstrptrvec&);
      static int erofs(CType,cstrvec&,const char *,cuint64_t,cstrptrvec&);
      static int ff(CType,cstrvec&,const char *,cuint64_t,cstrptrvec&);
      static int lfs(CType,cstrvec&,const char *,cuint64_t,cstrptrvec&);
      static int lus(CType,cstrvec&,const char *,cuint64_t,cstrptrvec&);
      static int mfs(CType,cstrvec&,const char *,cuint64_t,cstrptrvec&);
      static int newest(CType,cstrvec&,const char *,cuint64_t,cstrptrvec&);
      static int rand(CType,cstrvec&,const char *,cuint64_t,cstrptrvec&);
    };

  private:
    Enum::Type  _enum;
    std::string _str;
    Func::Ptr   _func;
    bool        _path_preserving;

  public:
    Policy()
      : _enum(invalid),
        _str(invalid),
        _func(invalid),
        _path_preserving(false)
    {
    }

    Policy(const Enum::Type   enum_,
           const std::string &str_,
           const Func::Ptr    func_,
           const bool         path_preserving_)
      : _enum(enum_),
        _str(str_),
        _func(func_),
        _path_preserving(path_preserving_)
    {
    }

    bool
    path_preserving() const
    {
      return _path_preserving;
    }

  public:
    operator const Enum::Type() const { return _enum; }
    operator const std::string&() const { return _str; }
    operator const Func::Ptr() const { return _func; }
    operator const Policy*() const { return this; }

    bool operator==(const Enum::Type enum_) const
    { return _enum == enum_; }
    bool operator==(const std::string &str_) const
    { return _str == str_; }
    bool operator==(const Func::Ptr func_) const
    { return _func == func_; }

    bool operator!=(const Policy &r) const
    { return _enum != r._enum; }

    bool operator<(const Policy &r) const
    { return _enum < r._enum; }

  public:
    static const Policy &find(const std::string&);
    static const Policy &find(const Enum::Type);

  public:
    static const std::vector<Policy> _policies_;
    static const Policy * const      policies;

    static const Policy &invalid;
    static const Policy &all;
    static const Policy &epall;
    static const Policy &epff;
    static const Policy &eplfs;
    static const Policy &eplus;
    static const Policy &epmfs;
    static const Policy &eprand;
    static const Policy &erofs;
    static const Policy &ff;
    static const Policy &lfs;
    static const Policy &lus;
    static const Policy &mfs;
    static const Policy &newest;
    static const Policy &rand;
  };
}
