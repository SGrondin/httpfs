using System;
using System.Collections.Generic;
using System.Linq;

namespace httpfsc.Business.Http.FileSystem.Results
{
    public class ListDirectoryResult
    {
        #region Constructors

        private ListDirectoryResult()
        {
            this.Folders = new List<Url>();
            this.Files = new List<Url>();
        }

        #endregion

        #region Properties

        public IEnumerable<Url> Folders { get; private set; }

        public IEnumerable<Url> Files { get; private set; }

        #endregion

        #region Methods

        public static ListDirectoryResult FromResponse(string response)
        {
            var splitResponse =
                response.Split(Environment.NewLine.ToCharArray()).Where(f => !string.IsNullOrWhiteSpace(f)).ToList();
            var folders = splitResponse.Where(f => f.EndsWith("/")).ToList();
            var files = splitResponse.Except(folders);

            var list = new ListDirectoryResult();
            list.Folders = folders.Select(f => new Url(f));
            list.Files = files.Select(f => new Url(f));

            return list;
        }

        public static ListDirectoryResult FromEmptyResponse()
        {
            return new ListDirectoryResult();
        }

        #endregion
    }
}