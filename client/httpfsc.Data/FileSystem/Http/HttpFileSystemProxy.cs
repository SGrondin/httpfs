using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Threading.Tasks;
using Flurl;
using Flurl.Http;

namespace httpfsc.Business.FileSystem.Http
{
    public class HttpFileSystemProxy
    {
        public Url ServerPath
        {
            get { return new Url(ConfigurationManager.AppSettings.Get("ServerPath")); }
        }

        public async Task<IEnumerable<string>> ListDirectory(Url path)
        {
            var files = await ServerPath
                .AppendPathSegment(path)
                .GetAsync();

            if (!files.Headers.Contains("IS-DIRECTORY"))
            {
                throw new Exception();
            }

            var list = await files.Content.ReadAsStringAsync();

            return list != null
                ? list.Split(Environment.NewLine.ToCharArray())
                : Enumerable.Empty<string>();
        }

        public async void DownloadFile(Url path)
        {
            var fileBytes = await ServerPath
                .AppendPathSegment(path)
                .GetAsync();

            if (fileBytes.Headers.Contains("IS-DIRECTORY"))
            {
                throw new Exception();
            }
        }
    }
}